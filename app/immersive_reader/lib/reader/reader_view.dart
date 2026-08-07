import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark.dart';
import '../models/document_model.dart';
import '../models/token.dart';
import '../progress/sm2_scheduler.dart';
import '../progress/word_progress_repository.dart';
import '../tts/tts_service.dart';
import 'reader_controller.dart';

// Wide desktop windows would otherwise stretch text edge-to-edge, which
// hurts readability - constrains the reading column to a comfortable
// measure regardless of window width.
const double _readableColumnMaxWidth = 720.0;

class ReaderView extends StatefulWidget {
  final DocumentModel document;
  final ReaderController controller;

  /// tokenId -> German translation, for tokens the replacement engine
  /// selected. Tokens not present here are never replaced. See
  /// ReplacementEngine.selectReplacements (SPEC.md section 4/6).
  final Map<String, String> replacements;

  /// Injectable for testing (a real TtsService talks to the OS's TTS
  /// engine via platform channels, which isn't available in widget
  /// tests) - defaults to a real one otherwise.
  final TtsService? ttsService;

  /// Injectable; null means progress events simply aren't recorded (used
  /// in tests, and before the caller has finished setting up the local
  /// database). Unlike ttsService, there is no default real instance
  /// created here - constructing one needs an async LocalDb.init() call,
  /// which the caller (HomePage) does once and passes down.
  final WordProgressRepository? wordProgressRepository;

  const ReaderView({
    super.key,
    required this.document,
    required this.controller,
    this.replacements = const {},
    this.ttsService,
    this.wordProgressRepository,
  });

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

/// A single search hit: which paragraph it's in (for the same
/// fraction-based approximate jump used by chapter/bookmark navigation)
/// and which token(s) to highlight - more than one for a multi-word query
/// that spans a run of consecutive tokens.
class _SearchMatch {
  final int paragraphIndex;
  final List<String> tokenIds;
  const _SearchMatch(this.paragraphIndex, this.tokenIds);
}

class _ReaderViewState extends State<ReaderView> {
  static const _debounceDuration = Duration(milliseconds: 400);
  static const _minFontSize = 10.0;
  static const _maxFontSize = 32.0;
  static const _autoReplaceBookmarkPrefsKey = 'auto_replace_bookmark';

  late ScrollController _scrollController;
  Timer? _saveDebounce;
  double _fontSize = 16.0;
  List<Bookmark> _bookmarks = [];
  bool _autoReplaceBookmark = false;
  late final TtsService _ttsService;

  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<_SearchMatch> _searchMatches = [];
  Set<String> _matchedTokenIds = {};
  int _currentMatchIndex = -1;
  Timer? _searchDebounce;
  bool _searchInProgress = false;
  // Bumped on every new search request so a slow/stale search (superseded
  // by further typing, or by closing the search bar) can detect it's no
  // longer wanted and discard its result instead of clobbering newer state.
  int _searchGeneration = 0;

  /// tokenIds the user has manually tapped back to English. Replaced tokens
  /// show German by default; toggling flips a single occurrence, not every
  /// occurrence of that word (SPEC.md section 1: "tap any translated word to
  /// toggle it back to English").
  final Set<String> _toggledToEnglish = {};

  /// tokenIds already recorded as an SM-2 exposure this session. _buildToken
  /// runs on every rebuild of a lazily-built ListView item (font size
  /// change, scroll-triggered rebuild, etc.), so without this guard the same
  /// token would be counted as a fresh exposure repeatedly.
  final Set<String> _exposedTokenIds = {};

  String get _prefsKey => 'scroll_position_${widget.document.document_id}';
  String get _bookmarksPrefsKey => 'bookmarks_${widget.document.document_id}';

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? TtsService();
    _scrollController = ScrollController()
      ..addListener(() {
        widget.controller.updateScrollPosition(_scrollController.position.pixels);
        _scheduleSave(_scrollController.position.pixels);
      });

    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScrollPosition());
    _loadBookmarks();
    _loadAutoReplaceSetting();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _ttsService.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _restoreScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getDouble(_prefsKey);
    if (savedPosition == null || !_scrollController.hasClients) return;

    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(savedPosition.clamp(0.0, maxExtent));
  }

  void _scheduleSave(double position) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_debounceDuration, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKey, position);
    });
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookmarksPrefsKey);
    if (raw == null || !mounted) return;
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    setState(() {
      _bookmarks = decoded.map((e) => Bookmark.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_bookmarks.map((b) => b.toJson()).toList());
    await prefs.setString(_bookmarksPrefsKey, encoded);
  }

  Future<void> _loadAutoReplaceSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_autoReplaceBookmarkPrefsKey);
    if (value == null || !mounted) return;
    setState(() => _autoReplaceBookmark = value);
  }

  Future<void> _saveAutoReplaceSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoReplaceBookmarkPrefsKey, value);
  }

  String _newBookmarkId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Adds a bookmark at the current scroll position. If auto-replace is on
  /// and a "current position" bookmark already exists, it's replaced in
  /// place (rather than adding a second one) and an Undo snackbar appears
  /// to restore it. Manually-placed bookmarks (added while auto-replace is
  /// off) are never touched by this - see Bookmark's doc comment.
  void _addBookmark() {
    final fraction = _currentFraction;

    if (_autoReplaceBookmark) {
      final existingIndex = _bookmarks.indexWhere((b) => b.isCurrentPosition);
      if (existingIndex != -1) {
        final old = _bookmarks[existingIndex];
        setState(() {
          _bookmarks[existingIndex] = Bookmark(id: _newBookmarkId(), fraction: fraction, isCurrentPosition: true);
        });
        _saveBookmarks();
        _showBookmarkMovedSnackBar(old);
        return;
      }
    }

    setState(() {
      _bookmarks.add(Bookmark(id: _newBookmarkId(), fraction: fraction, isCurrentPosition: _autoReplaceBookmark));
    });
    _saveBookmarks();
  }

  void _showBookmarkMovedSnackBar(Bookmark old) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bookmark moved to ${(_currentFraction * 100).round()}%'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final currentIndex = _bookmarks.indexWhere((b) => b.isCurrentPosition);
            if (currentIndex == -1) return;
            setState(() => _bookmarks[currentIndex] = old);
            _saveBookmarks();
          },
        ),
      ),
    );
  }

  void _removeBookmark(Bookmark bookmark) {
    setState(() => _bookmarks.removeWhere((b) => b.id == bookmark.id));
    _saveBookmarks();
  }

  void _showBookmarksList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final sorted = [..._bookmarks]..sort((a, b) => a.fraction.compareTo(b.fraction));
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Auto-replace forward bookmarks'),
                  subtitle: const Text(
                    'Bookmarking further ahead moves your current-position bookmark '
                    'instead of adding a new one',
                  ),
                  value: _autoReplaceBookmark,
                  onChanged: (value) {
                    setState(() => _autoReplaceBookmark = value);
                    setSheetState(() {});
                    _saveAutoReplaceSetting(value);
                  },
                ),
                const Divider(height: 1),
                if (sorted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No bookmarks yet'),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: sorted.map((bookmark) {
                        return ListTile(
                          leading: Icon(bookmark.isCurrentPosition ? Icons.star : Icons.bookmark_border),
                          title: Text('${(bookmark.fraction * 100).round()}% through'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove bookmark',
                            onPressed: () {
                              _removeBookmark(bookmark);
                              setSheetState(() {});
                            },
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _jumpToFraction(bookmark.fraction);
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _adjustFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    });
  }

  void _toggleToken(Token token) {
    final tokenId = token.tokenId;
    final wasShowingGerman = !_toggledToEnglish.contains(tokenId);
    setState(() {
      if (!_toggledToEnglish.add(tokenId)) {
        _toggledToEnglish.remove(tokenId);
      }
    });
    final outcome = wasShowingGerman
        ? ExposureOutcome.toggledBack
        : ExposureOutcome.toggledForward;
    unawaited(
      widget.wordProgressRepository?.recordExposure(
        token.text.toLowerCase(),
        outcome,
      ),
    );
  }

  Widget _buildToken(Token token) {
    final highlightColor = _highlightColorFor(token.tokenId);
    final germanText = widget.replacements[token.tokenId];
    if (germanText == null) {
      return Text('${token.text} ', style: TextStyle(fontSize: _fontSize, backgroundColor: highlightColor));
    }

    final showingGerman = !_toggledToEnglish.contains(token.tokenId);
    if (showingGerman && _exposedTokenIds.add(token.tokenId)) {
      unawaited(
        widget.wordProgressRepository?.recordExposure(
          token.text.toLowerCase(),
          ExposureOutcome.neutral,
        ),
      );
    }
    return GestureDetector(
      onTap: () => _toggleToken(token),
      onLongPress: () => _ttsService.speak(germanText),
      child: Tooltip(
        message: 'Tap to toggle English/German · Long-press to hear pronunciation',
        triggerMode: TooltipTriggerMode.manual,
        child: Text(
          '${showingGerman ? germanText : token.text} ',
          style: TextStyle(
            fontSize: _fontSize,
            color: showingGerman ? Colors.blue : null,
            decoration: showingGerman ? TextDecoration.underline : null,
            backgroundColor: highlightColor,
          ),
        ),
      ),
    );
  }

  // Paragraphs are capped at a fairly uniform size (see
  // DocumentParser.buildParagraphs), so a fraction of the total paragraph
  // count is a good approximation of a fraction of total scroll extent.
  // Exact pixel-perfect jumps aren't worth the complexity of tracking
  // per-item heights in a lazy ListView.builder for Phase 1. Shared by
  // chapter jumps and the Ctrl+G go-to-page dialog below.
  //
  // ListView.builder only knows the real height of whatever's actually been
  // laid out - maxScrollExtent for everything else is an ESTIMATE
  // extrapolated from those built items. Jumping straight from near the top
  // of a document with many thousands of paragraphs to, say, 90% using an
  // estimate built from the first few on-screen paragraphs can land nowhere
  // near the real target if paragraph density varies across the document.
  // Jumping repeatedly lets the estimate refine using items actually near
  // the target each time, converging on the right spot; the final hop is
  // animated for a smooth landing.
  Future<void> _jumpToFraction(double fraction) async {
    if (!_scrollController.hasClients) return;
    final clampedFraction = fraction.clamp(0.0, 1.0);

    double target = clampedFraction * _scrollController.position.maxScrollExtent;
    for (var i = 0; i < 6; i++) {
      if (!_scrollController.hasClients) return;
      target = target.clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(target);
      await WidgetsBinding.instance.endOfFrame;
      if (!_scrollController.hasClients) return;
      final refined =
          (clampedFraction * _scrollController.position.maxScrollExtent).clamp(0.0, _scrollController.position.maxScrollExtent);
      if ((refined - target).abs() < 1.0) break;
      target = refined;
    }

    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _jumpToChapter(ChapterMarker chapter) {
    if (widget.document.paragraphs.isEmpty) return;
    _jumpToFraction(chapter.paragraphIndex / widget.document.paragraphs.length);
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: widget.document.chapters.map((chapter) {
            return ListTile(
              title: Text(chapter.title),
              onTap: () {
                Navigator.pop(context);
                _jumpToChapter(chapter);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  double get _currentFraction {
    if (!_scrollController.hasClients) return 0.0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return 0.0;
    return (_scrollController.position.pixels / maxExtent).clamp(0.0, 1.0);
  }

  // "Page" here means paragraph number (1-based) - the app doesn't paginate,
  // so a paragraph index is the closest equivalent, consistent with the
  // fraction-based navigation used everywhere else in this file.
  Future<void> _showGoToPageDialog() async {
    final totalPages = widget.document.paragraphs.length;
    if (totalPages == 0) return;

    final controller = TextEditingController();
    int? parseValidPage() {
      final page = int.tryParse(controller.text);
      if (page == null || page < 1 || page > totalPages) return null;
      return page;
    }

    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Page 1-$totalPages'),
          onSubmitted: (_) {
            final validPage = parseValidPage();
            if (validPage != null) Navigator.pop(dialogContext, validPage);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final validPage = parseValidPage();
              if (validPage != null) Navigator.pop(dialogContext, validPage);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );

    if (page != null) _jumpToFraction((page - 1) / totalPages);
  }

  // Scans in small paragraph batches, yielding to the event loop between
  // batches, so a huge document doesn't block a single frame long enough to
  // stall scrolling/animations elsewhere in the reader - unlike a single
  // tight synchronous loop, the UI stays responsive throughout. [generation]
  // is checked after every yield so an old search abandons its work as soon
  // as it's superseded, rather than racing a newer one to completion.
  static const _searchYieldBatchSize = 20;

  Future<List<_SearchMatch>> _findMatchesAsync(String query, int generation) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];
    final lowerQuery = trimmedQuery.toLowerCase();
    final matches = <_SearchMatch>[];
    final paragraphs = widget.document.paragraphs;
    for (var i = 0; i < paragraphs.length; i++) {
      for (final sentence in paragraphs[i].sentences) {
        final tokens = sentence.tokens;
        // Join the sentence's tokens the same way _buildToken renders them
        // ("text " per token), tracking each token's [start, end) offset in
        // that string, so a multi-word query can match a run of consecutive
        // tokens - not just a single token's own text.
        final buffer = StringBuffer();
        final starts = <int>[];
        final ends = <int>[];
        for (final token in tokens) {
          starts.add(buffer.length);
          buffer.write(token.text);
          ends.add(buffer.length);
          buffer.write(' ');
        }
        final sentenceText = buffer.toString().toLowerCase();

        var searchFrom = 0;
        while (true) {
          final matchStart = sentenceText.indexOf(lowerQuery, searchFrom);
          if (matchStart == -1) break;
          final matchEnd = matchStart + lowerQuery.length;
          final matchedTokenIds = <String>[
            for (var t = 0; t < tokens.length; t++)
              if (starts[t] < matchEnd && ends[t] > matchStart) tokens[t].tokenId,
          ];
          if (matchedTokenIds.isNotEmpty) {
            matches.add(_SearchMatch(i, matchedTokenIds));
          }
          searchFrom = matchStart + 1;
        }
      }
      if (i % _searchYieldBatchSize == _searchYieldBatchSize - 1) {
        await Future<void>.delayed(Duration.zero);
        if (generation != _searchGeneration) return matches;
      }
    }
    return matches;
  }

  void _runSearch(String query) {
    _searchDebounce?.cancel();
    setState(() => _searchQuery = query);

    final generation = ++_searchGeneration;
    _searchDebounce = Timer(_debounceDuration, () => _executeSearch(query, generation));
  }

  Future<void> _executeSearch(String query, int generation) async {
    if (!mounted || generation != _searchGeneration) return;
    setState(() => _searchInProgress = true);

    final matches = await _findMatchesAsync(query, generation);

    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _searchMatches = matches;
      _matchedTokenIds = matches.expand((m) => m.tokenIds).toSet();
      _currentMatchIndex = matches.isEmpty ? -1 : 0;
      _searchInProgress = false;
    });
    if (_currentMatchIndex >= 0) _jumpToMatch(_currentMatchIndex);
  }

  void _jumpToMatch(int index) {
    if (index < 0 || index >= _searchMatches.length) return;
    final totalParagraphs = widget.document.paragraphs.length;
    if (totalParagraphs == 0) return;
    setState(() => _currentMatchIndex = index);
    _jumpToFraction(_searchMatches[index].paragraphIndex / totalParagraphs);
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    _jumpToMatch((_currentMatchIndex + 1) % _searchMatches.length);
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    _jumpToMatch((_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length);
  }

  void _openSearch() {
    if (!_searchVisible) {
      setState(() => _searchVisible = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchGeneration++; // invalidate any search still in flight
    setState(() {
      _searchVisible = false;
      _searchController.clear();
      _searchQuery = '';
      _searchMatches = [];
      _matchedTokenIds = {};
      _currentMatchIndex = -1;
      _searchInProgress = false;
    });
  }

  Color? _highlightColorFor(String tokenId) {
    if (_currentMatchIndex >= 0 && _searchMatches[_currentMatchIndex].tokenIds.contains(tokenId)) {
      return Colors.orange.shade400;
    }
    if (_matchedTokenIds.contains(tokenId)) {
      return Colors.yellow.shade300;
    }
    return null;
  }

  Widget _buildSearchBar() {
    final hasMatches = _searchMatches.isNotEmpty;
    final hasQuery = _searchQuery.trim().isNotEmpty;
    final resultText = hasMatches
        ? '${_currentMatchIndex + 1}/${_searchMatches.length}'
        : hasQuery
            ? 'No results'
            : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Search in document',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: _runSearch,
              onSubmitted: (_) => _nextMatch(),
            ),
          ),
          const SizedBox(width: 8),
          // A fixed-size slot so the spinner replacing the match-count text
          // while a large document is still being searched doesn't shift
          // the buttons next to it around.
          SizedBox(
            width: 56,
            child: _searchInProgress
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Text(resultText),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: 'Previous match',
            onPressed: hasMatches && !_searchInProgress ? _previousMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: 'Next match',
            onPressed: hasMatches && !_searchInProgress ? _nextMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close search',
            onPressed: _closeSearch,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): _showGoToPageDialog,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchVisible) _closeSearch();
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Row(
              children: [
                if (widget.document.chapters.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.list),
                    tooltip: 'Chapters',
                    onPressed: _showChapterList,
                  ),
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: 'Bookmark this page',
                  onPressed: _addBookmark,
                ),
                IconButton(
                  icon: const Icon(Icons.bookmarks_outlined),
                  tooltip: 'Bookmarks',
                  onPressed: _showBookmarksList,
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search (Ctrl+F)',
                  onPressed: _openSearch,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, _) {
                        final fraction = _currentFraction;
                        return Row(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  void seekToLocalX(double dx) {
                                    final target = (dx / constraints.maxWidth).clamp(0.0, 1.0);
                                    _jumpToFraction(target);
                                  }

                                  return MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (details) => seekToLocalX(details.localPosition.dx),
                                      onHorizontalDragUpdate: (details) => seekToLocalX(details.localPosition.dx),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: LinearProgressIndicator(value: fraction),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${(fraction * 100).round()}%'),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: 'Decrease font size',
                  onPressed: _fontSize > _minFontSize ? () => _adjustFontSize(-2) : null,
                ),
                Text('${_fontSize.round()}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Increase font size',
                  onPressed: _fontSize < _maxFontSize ? () => _adjustFontSize(2) : null,
                ),
              ],
            ),
            if (_searchVisible) _buildSearchBar(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _readableColumnMaxWidth),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: widget.document.paragraphs.length,
                    itemBuilder: (context, index) {
                      final paragraph = widget.document.paragraphs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: paragraph.sentences.map((sentence) {
                            return Wrap(
                              children: sentence.tokens.map(_buildToken).toList(),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
