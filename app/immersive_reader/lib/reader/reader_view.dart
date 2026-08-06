import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_model.dart';
import '../models/token.dart';
import 'reader_controller.dart';
import 'reading_progress_view.dart';

class ReaderView extends StatefulWidget {
  final DocumentModel document;
  final ReaderController controller;

  /// tokenId -> German translation, for tokens the replacement engine
  /// selected. Tokens not present here are never replaced. See
  /// ReplacementEngine.selectReplacements (SPEC.md section 4/6).
  final Map<String, String> replacements;

  const ReaderView({
    super.key,
    required this.document,
    required this.controller,
    this.replacements = const {},
  });

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  static const _debounceDuration = Duration(milliseconds: 400);
  static const _minFontSize = 10.0;
  static const _maxFontSize = 32.0;

  late ScrollController _scrollController;
  Timer? _saveDebounce;
  double _fontSize = 16.0;

  /// tokenIds the user has manually tapped back to English. Replaced tokens
  /// show German by default; toggling flips a single occurrence, not every
  /// occurrence of that word (SPEC.md section 1: "tap any translated word to
  /// toggle it back to English").
  final Set<String> _toggledToEnglish = {};

  String get _prefsKey => 'scroll_position_${widget.document.document_id}';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        widget.controller.updateScrollPosition(_scrollController.position.pixels);
        _scheduleSave(_scrollController.position.pixels);
      });

    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScrollPosition());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _scrollController.dispose();
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

  void _adjustFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    });
  }

  void _toggleToken(String tokenId) {
    setState(() {
      if (!_toggledToEnglish.add(tokenId)) {
        _toggledToEnglish.remove(tokenId);
      }
    });
  }

  Widget _buildToken(Token token) {
    final germanText = widget.replacements[token.tokenId];
    if (germanText == null) {
      return Text('${token.text} ', style: TextStyle(fontSize: _fontSize));
    }

    final showingGerman = !_toggledToEnglish.contains(token.tokenId);
    return GestureDetector(
      onTap: () => _toggleToken(token.tokenId),
      child: Text(
        '${showingGerman ? germanText : token.text} ',
        style: TextStyle(
          fontSize: _fontSize,
          color: showingGerman ? Colors.blue : null,
          decoration: showingGerman ? TextDecoration.underline : null,
        ),
      ),
    );
  }

  // Paragraphs are capped at a fairly uniform size (see
  // DocumentParser.buildParagraphs), so a fraction of the total paragraph
  // count is a good approximation of a fraction of total scroll extent.
  // Exact pixel-perfect jumps aren't worth the complexity of tracking
  // per-item heights in a lazy ListView.builder for Phase 1. Shared by
  // chapter jumps, the reading-progress page's slider/chapter taps, and
  // the Ctrl+G go-to-page dialog below.
  void _jumpToFraction(double fraction) {
    if (!_scrollController.hasClients) return;
    final target = fraction * _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
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

  Future<void> _openReadingProgress() async {
    final fraction = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingProgressView(
          documentTitle: widget.document.title,
          totalParagraphs: widget.document.paragraphs.length,
          currentFraction: _currentFraction,
          chapters: widget.document.chapters,
        ),
      ),
    );
    if (fraction != null) _jumpToFraction(fraction);
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

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): _showGoToPageDialog,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.document.chapters.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.list),
                    tooltip: 'Chapters',
                    onPressed: _showChapterList,
                  ),
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: 'Reading progress',
                  onPressed: _openReadingProgress,
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
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.document.paragraphs.length,
                itemBuilder: (context, index) {
                  final paragraph = widget.document.paragraphs[index];
                  return Column(
                    children: paragraph.sentences.map((sentence) {
                      return Wrap(
                        children: sentence.tokens.map(_buildToken).toList(),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
