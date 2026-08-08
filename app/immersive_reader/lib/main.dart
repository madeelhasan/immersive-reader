import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dictionary/dictionary_repository.dart';
import 'library/reading_progress_lookup.dart';
import 'library/recent_documents_repository.dart';
import 'models/document_model.dart';
import 'models/recent_document.dart';
import 'models/token.dart';
import 'parsers/background_parse.dart';
import 'progress/local_user_id.dart';
import 'progress/word_progress_repository.dart';
import 'reader/reader_controller.dart';
import 'reader/reader_view.dart';
import 'replacement/replacement_engine.dart';
import 'storage/document_cache_repository.dart';
import 'storage/local_db.dart';
import 'theme/reader_font.dart';
import 'theme/reader_theme_palette.dart';
import 'vocabulary/vocabulary_repository.dart';

Future<void> main() async {
  // sqflite's own platform-channel implementation only covers Android/iOS/
  // macOS - Windows and Linux have no native backend, so openDatabase()
  // would throw immediately without this, silently disabling both document
  // caching and word-progress tracking (see _initLocalDb's catch-and-degrade
  // below, which otherwise makes that failure invisible).
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    WidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // sqflite_common_ffi's default database directory is relative to the
    // process's *working directory*
    // (.dart_tool/sqflite_common_ffi/databases) - correct for a normal
    // shortcut/double-click launch (Windows sets cwd to the exe's own
    // folder), but silently wrong, and unrecoverable by an uninstaller,
    // for any launch path that doesn't. Pinning it to the same stable
    // per-user directory shared_preferences already uses means there's
    // exactly one place on disk this app ever writes to, regardless of how
    // it's launched - found while verifying the Windows installer's
    // uninstall actually cleans up everything it creates.
    final supportDir = await getApplicationSupportDirectory();
    // ignore: deprecated_member_use
    await databaseFactory.setDatabasesPath(supportDir.path);
  }
  runApp(const ImmersiveReaderApp());
}

class ImmersiveReaderApp extends StatefulWidget {
  const ImmersiveReaderApp({super.key});

  @override
  State<ImmersiveReaderApp> createState() => _ImmersiveReaderAppState();
}

class _ImmersiveReaderAppState extends State<ImmersiveReaderApp> {
  static const _themeModePrefsKey = 'theme_mode';
  static const _themePalettePrefsKey = 'theme_palette';
  static const _readerFontPrefsKey = 'reader_font';

  ThemeMode _themeMode = ThemeMode.system;
  ReaderThemePalette _themePalette = ReaderThemePalette.warm;
  ReaderFont _readerFont = ReaderFont.georgia;

  @override
  void initState() {
    super.initState();
    _restoreThemeMode();
    _restoreThemePalette();
    _restoreReaderFont();
  }

  Future<void> _restoreThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeModePrefsKey);
    final mode = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    if (!mounted || mode == _themeMode) return;
    setState(() => _themeMode = mode);
  }

  Future<void> _restoreThemePalette() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themePalettePrefsKey);
    final palette =
        ReaderThemePalette.values.firstWhere((p) => p.name == saved, orElse: () => ReaderThemePalette.warm);
    if (!mounted || palette == _themePalette) return;
    setState(() => _themePalette = palette);
  }

  Future<void> _restoreReaderFont() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_readerFontPrefsKey);
    final font = ReaderFont.values.firstWhere((f) => f.name == saved, orElse: () => ReaderFont.georgia);
    if (!mounted || font == _readerFont) return;
    setState(() => _readerFont = font);
  }

  // Georgia ships with Windows, so a serif reading font needs no new font
  // asset or runtime download, matching the app's offline-first bent -
  // colors themselves come from the selected ReaderThemePalette
  // (lib/theme/reader_theme_palette.dart), not fixed constants here.
  static const _readingFontFamily = 'Georgia';

  void _cycleThemeMode() {
    final next = switch (_themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    setState(() => _themeMode = next);
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_themeModePrefsKey, next.name));
  }

  void _setThemePalette(ReaderThemePalette palette) {
    setState(() => _themePalette = palette);
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_themePalettePrefsKey, palette.name));
  }

  void _setReaderFont(ReaderFont font) {
    setState(() => _readerFont = font);
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_readerFontPrefsKey, font.name));
  }

  static ThemeData _buildTheme({required Brightness brightness, required PaletteColors colors}) {
    final base = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: colors.accent, brightness: brightness)
          .copyWith(surface: colors.background),
      appBarTheme: AppBarTheme(backgroundColor: colors.background, foregroundColor: colors.text, elevation: 0),
    );
    return base.copyWith(
      textTheme:
          base.textTheme.apply(fontFamily: _readingFontFamily, bodyColor: colors.text, displayColor: colors.text),
      primaryTextTheme: base.primaryTextTheme
          .apply(fontFamily: _readingFontFamily, bodyColor: colors.text, displayColor: colors.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lesefluss',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(brightness: Brightness.light, colors: _themePalette.light),
      darkTheme: _buildTheme(brightness: Brightness.dark, colors: _themePalette.dark),
      themeMode: _themeMode,
      home: HomePage(
        themeMode: _themeMode,
        onToggleTheme: _cycleThemeMode,
        themePalette: _themePalette,
        onThemePaletteChanged: _setThemePalette,
        readerFont: _readerFont,
        onReaderFontChanged: _setReaderFont,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final ReaderThemePalette themePalette;
  final ValueChanged<ReaderThemePalette> onThemePaletteChanged;
  final ReaderFont readerFont;
  final ValueChanged<ReaderFont> onReaderFontChanged;

  const HomePage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.themePalette,
    required this.onThemePaletteChanged,
    required this.readerFont,
    required this.onReaderFontChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _germanLevelPrefsKey = 'german_level';
  static const _hasSeenOnboardingPrefsKey = 'has_seen_onboarding';

  final ReaderController _controller = ReaderController();
  final VocabularyRepository _vocabularyRepository = VocabularyRepository();
  final RecentDocumentsRepository _recentDocumentsRepository = RecentDocumentsRepository();
  DocumentModel? _document;
  List<Token> _tokens = [];
  Map<String, String> _replacements = {};
  String? _error;
  String _germanLevel = 'A1';
  String? _loadingFileName;
  WordProgressRepository? _wordProgressRepository;
  DocumentCacheRepository? _documentCacheRepository;
  // Unlike the two above, needs no async setup to construct - it only
  // decompresses the bundled FreeDict asset lazily, on first lookup - so
  // it's created eagerly here rather than inside _initLocalDb.
  final DictionaryRepository _dictionaryRepository = DictionaryRepository();
  List<RecentDocument> _recentDocuments = [];
  /// Recently-opened documents that still have a bookmark and aren't
  /// finished yet (SPEC.md section 7 addendum) - a subset of
  /// _recentDocuments, shown in an extra "Continue reading" section above
  /// the full list. Recomputed on every _refreshRecentDocuments() call
  /// rather than persisted, so a book drops out on its own once its
  /// bookmarks are all removed or it's read to the end.
  List<RecentDocument> _bookmarkedInProgress = [];
  Timer? _levelAdvanceDebounce;
  // Starts true (not false) so onboarding doesn't flash on screen for one
  // frame on every launch while _restoreOnboardingSeen's async read is still
  // in flight - a returning reader would see it, dismiss it, and it'd still
  // have cost them a visible flicker.
  bool _hasSeenOnboarding = true;

  bool get _isLoading => _loadingFileName != null;

  @override
  void initState() {
    super.initState();
    _restoreGermanLevel();
    _restoreOnboardingSeen();
    _initLocalDb();
    _refreshRecentDocuments();
  }

  @override
  void dispose() {
    _levelAdvanceDebounce?.cancel();
    super.dispose();
  }

  /// Reloads the recent-documents list and recomputes which of them belong
  /// in "Continue reading" (SPEC.md section 7 addendum). The single place
  /// that touches both lists together, so every caller (initial load, after
  /// opening a document, after removing one) stays in sync automatically.
  Future<void> _refreshRecentDocuments() async {
    final recent = await _recentDocumentsRepository.getRecent();
    final prefs = await SharedPreferences.getInstance();
    final lookup = ReadingProgressLookup(prefs);
    final inProgress = recent.where(lookup.isInProgress).toList();
    if (!mounted) return;
    setState(() {
      _recentDocuments = recent;
      _bookmarkedInProgress = inProgress;
    });
  }

  /// LocalDb.init() is async, so neither repository is available on the
  /// very first frame - ReaderView treats a null wordProgressRepository as
  /// "don't track events yet", and _openPath treats a null
  /// documentCacheRepository as "always parse fresh," both fine for the
  /// brief window before this completes. Also swallows failures (e.g. no
  /// sqflite platform channel in a plain widget test) the same way
  /// VocabularyRepository falls back rather than crashing app startup.
  /// One shared LocalDb/Database instance for both repositories - two
  /// separate connections to the same on-disk sqlite file would risk
  /// locking contention between them.
  Future<void> _initLocalDb() async {
    final WordProgressRepository wordProgressRepository;
    final DocumentCacheRepository documentCacheRepository;
    try {
      final db = LocalDb();
      await db.init();
      final userId = await getOrCreateLocalUserId();
      wordProgressRepository = WordProgressRepository(db, userId);
      documentCacheRepository = DocumentCacheRepository(db);
    } catch (e) {
      // Genuinely expected on platforms with no sqflite backend at all
      // (plain widget tests) - degrading silently there is correct. On a
      // real desktop run this should never fire (main() wires up
      // databaseFactoryFfi first); debugPrint means a regression here is
      // at least visible in the console instead of silently disabling
      // caching/progress-tracking again with no trace.
      debugPrint('LocalDb.init() failed - document caching and word-progress tracking are disabled: $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _wordProgressRepository = wordProgressRepository;
      _documentCacheRepository = documentCacheRepository;
    });
  }

  Future<void> _restoreGermanLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_germanLevelPrefsKey);
    if (saved == null || !ReplacementEngine.levelOrder.contains(saved)) return;
    setState(() => _germanLevel = saved);
    _recomputeReplacements();
  }

  Future<void> _restoreOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_hasSeenOnboardingPrefsKey) ?? false;
    if (!mounted || seen == _hasSeenOnboarding) return;
    setState(() => _hasSeenOnboarding = seen);
  }

  Future<void> _dismissOnboarding() async {
    setState(() => _hasSeenOnboarding = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingPrefsKey, true);
  }

  Future<void> _setGermanLevel(String level) async {
    setState(() => _germanLevel = level);
    _recomputeReplacements();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_germanLevelPrefsKey, level);
  }

  /// ReaderView calls this whenever an exposure just brought some word to
  /// 'learned' - debounced since several words can cross that threshold in
  /// quick succession while reading, and each check below re-fetches the
  /// full vocabulary and progress tables, not worth doing for every single
  /// one individually.
  void _onWordLearned() {
    _levelAdvanceDebounce?.cancel();
    _levelAdvanceDebounce = Timer(const Duration(seconds: 2), _checkAutoLevelAdvance);
  }

  /// SPEC.md 4.3: once every vocabulary entry eligible at the reader's
  /// current level is 'learned', advance one level automatically. The rule
  /// itself (ReplacementEngine.nextLevelIfComplete) is a pure function, unit
  /// tested directly - this is just fetching its inputs and applying the
  /// resulting side effects (persist the new level, notify the reader).
  Future<void> _checkAutoLevelAdvance() async {
    final repository = _wordProgressRepository;
    if (repository == null) return;

    final vocabulary = await _vocabularyRepository.load();
    final progress = await repository.getAllProgress();
    final nextLevel = ReplacementEngine().nextLevelIfComplete(_germanLevel, vocabulary, progress);
    if (nextLevel == null) return;

    final completedLevel = _germanLevel;
    await _setGermanLevel(nextLevel);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("You've learned every $completedLevel word - leveled up to $nextLevel!")),
    );
  }

  /// Re-rolls replacements for the currently open document against the
  /// current _germanLevel. A no-op if no document is open yet - _openFile
  /// picks up _germanLevel directly once one is.
  Future<void> _recomputeReplacements() async {
    if (_document == null || _tokens.isEmpty) return;
    final replacements = await _computeReplacements(_tokens);
    if (!mounted) return;
    setState(() => _replacements = replacements);
  }

  /// Uses SPEC.md 4.2's depth/word-status probabilities
  /// (ReplacementEngine.selectReplacementsWithProgress) once the local
  /// progress repository is ready; falls back to the flat per-level rate
  /// (selectReplacements) before that async init completes or if it failed.
  Future<Map<String, String>> _computeReplacements(List<Token> tokens) async {
    final vocabulary = await _vocabularyRepository.load();
    final repository = _wordProgressRepository;
    if (repository == null) {
      return ReplacementEngine().selectReplacements(
        tokens,
        vocabulary,
        germanLevel: _germanLevel,
      );
    }
    final progress = await repository.getAllProgress();
    return ReplacementEngine().selectReplacementsWithProgress(
      tokens,
      vocabulary,
      progress,
      germanLevel: _germanLevel,
    );
  }

  Future<void> _openFile() async {
    String? path;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'docx', 'epub', 'pdf', 'html', 'htm'],
      );
      path = result?.files.single.path;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the file picker: $e');
      return;
    }
    if (path == null) return;
    await _openPath(path);
  }

  /// Parses and opens the file at [path], updating replacements and (on
  /// success) the recent-documents list. [fromRecent] marks a tap on an
  /// already-recorded recent-documents entry - if that file has since been
  /// moved or deleted, the stale entry is removed instead of surfacing a
  /// generic parse error (SPEC.md section 7).
  Future<void> _openPath(String path, {bool fromRecent = false}) async {
    if (fromRecent && !File(path).existsSync()) {
      final documentId = p.basenameWithoutExtension(path);
      await _recentDocumentsRepository.remove(documentId);
      await _refreshRecentDocuments();
      if (!mounted) return;
      setState(() => _error = 'That file could not be found - it may have been moved or deleted.');
      return;
    }

    setState(() => _loadingFileName = p.basename(path));
    // Ensures the spinner's first frame actually paints before anything
    // else runs - cheap insurance for the moment between compute()'s own
    // isolate-spawn overhead and its first real yield.
    await WidgetsBinding.instance.endOfFrame;

    try {
      final cached = await _documentCacheRepository?.get(path);
      final DocumentModel document;
      if (cached != null) {
        document = cached;
      } else {
        // Parsing (file I/O, decompression, PDF text extraction,
        // tokenization) runs on a background isolate via compute() - a
        // real PDF can take several seconds of genuinely synchronous CPU
        // work (measured: ~8s for a 638-page fixture) that would otherwise
        // freeze the entire UI, including the loading spinner's own
        // animation, since Dart isolates don't share a run loop with the
        // main one. A pathologically slow or stuck parse (a hostile or
        // corrupted file) should still fail with a message the user can
        // act on, not leave the loading spinner stuck forever with no way
        // out - hence the timeout.
        document = await compute(parseDocumentInBackground, path).timeout(const Duration(seconds: 60));
        unawaited(_documentCacheRepository?.put(path, document));
      }
      final tokens = document.paragraphs
          .expand((para) => para.sentences)
          .expand((sentence) => sentence.tokens)
          .toList();
      final hasText = tokens.isNotEmpty;

      if (!hasText) {
        setState(() {
          _document = null;
          _tokens = [];
          _replacements = {};
          _error = 'No text could be extracted from this file. '
              'If it\'s a PDF, it may be a scanned/image-based document '
              'with no selectable text layer.';
        });
        return;
      }

      final replacements = await _computeReplacements(tokens);

      await _recentDocumentsRepository.recordOpened(RecentDocument(
        documentId: document.document_id,
        title: document.title,
        filePath: path,
        format: p.extension(path).replaceFirst('.', '').toLowerCase(),
        lastOpenedAt: DateTime.now(),
        paragraphCount: document.paragraphs.length,
      ));
      await _refreshRecentDocuments();

      if (!mounted) return;
      setState(() {
        _document = document;
        _tokens = tokens;
        _replacements = replacements;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _document = null;
        _tokens = [];
        _replacements = {};
        _error = e is TimeoutException
            ? 'This file is taking too long to open - it may be unusually large or complex.'
            : 'Could not open file: $e';
      });
    } finally {
      setState(() => _loadingFileName = null);
    }
  }

  /// Returns to the recent-documents/library view. Doesn't need to touch
  /// the recent-documents list itself - the document being closed was
  /// already recorded there (moved to the front) when it was opened.
  void _closeDocument() {
    setState(() {
      _document = null;
      _tokens = [];
      _replacements = {};
      _error = null;
    });
  }

  IconData get _themeIcon => switch (widget.themeMode) {
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.system => Icons.brightness_auto,
      };

  String get _themeLabel => switch (widget.themeMode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Match system',
      };

  /// Asks a first-time reader to pick their starting German level before
  /// their very first import, instead of silently defaulting to A1 with no
  /// prompt - the level is otherwise easy to miss (previously only visible
  /// inside Settings). Dismissing without choosing (tapping outside) just
  /// keeps the A1 default, same as before this existed - it's a nudge
  /// toward a more accurate starting point, not a gate.
  Future<void> _showFirstLevelPickerThenOpenFile() async {
    var selected = _germanLevel;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("What's your German level?"),
          // Scrollable, not a plain Column: AlertDialog doesn't scroll its
          // content by default, and six RadioListTiles plus the intro text
          // overflow its default height on a modest window/test viewport.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "We'll start you with the right amount of German - "
                  'you can always change this later in Settings.',
                ),
                const SizedBox(height: 16),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (level) {
                    if (level == null) return;
                    setDialogState(() => selected = level);
                  },
                  child: Column(
                    children: [
                      for (final level in ReplacementEngine.levelOrder)
                        RadioListTile<String>(value: level, title: Text(level)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (selected != _germanLevel) await _setGermanLevel(selected);
    _dismissOnboarding();
    _openFile();
  }

  /// One sheet, two clearly separate sections: settings that affect the app
  /// itself (currently just theme) versus settings about the reader/learner
  /// (currently just CEFR level) - previously both sat as flat, equal-weight
  /// AppBar icons with no indication they're different kinds of setting.
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // Scrollable, not a plain Column: with the theme-palette
              // picker added alongside the CEFR level picker, the sheet's
              // natural content height can exceed the available screen
              // height - SingleChildScrollView lets it scroll instead of
              // overflowing/clipping.
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('APP', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                    ListTile(
                      leading: Icon(_themeIcon),
                      title: const Text('Theme'),
                      subtitle: Text(_themeLabel),
                      onTap: () {
                        widget.onToggleTheme();
                        setSheetState(() {});
                      },
                    ),
                    RadioGroup<ReaderThemePalette>(
                      groupValue: widget.themePalette,
                      onChanged: (selected) {
                        if (selected == null) return;
                        widget.onThemePaletteChanged(selected);
                        setSheetState(() {});
                      },
                      child: Column(
                        children: [
                          for (final palette in ReaderThemePalette.values)
                            RadioListTile<ReaderThemePalette>(
                              value: palette,
                              title: Text(palette.label),
                              subtitle: palette.isHighContrast
                                  ? const Text('High contrast, bolder, larger minimum text')
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('READING & VOCABULARY',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 16, top: 8),
                      child: Text('Font', style: TextStyle(fontSize: 12, letterSpacing: 1)),
                    ),
                    RadioGroup<ReaderFont>(
                      groupValue: widget.readerFont,
                      onChanged: (selected) {
                        if (selected == null) return;
                        widget.onReaderFontChanged(selected);
                        setSheetState(() {});
                      },
                      child: Column(
                        children: [
                          for (final font in ReaderFont.values)
                            RadioListTile<ReaderFont>(
                              value: font,
                              title: Text(font.label, style: TextStyle(fontFamily: font.fontFamily, fontSize: 18)),
                            ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 16, top: 8),
                      child: Text('German level', style: TextStyle(fontSize: 12, letterSpacing: 1)),
                    ),
                    RadioGroup<String>(
                      groupValue: _germanLevel,
                      onChanged: (selected) {
                        if (selected == null) return;
                        _setGermanLevel(selected);
                        setSheetState(() {});
                      },
                      child: Column(
                        children: [
                          for (final level in ReplacementEngine.levelOrder)
                            RadioListTile<String>(value: level, title: Text(level)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Replacements are drawn from your level and everything below it, and get denser at higher levels. '
                        'Level up automatically once every word at your current level is learned.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _document != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to library',
                onPressed: _isLoading ? null : _closeDocument,
              )
            : null,
        title: Text(_document?.title ?? 'Lesefluss'),
        actions: [
          // Always-visible level indicator - previously only discoverable
          // by opening Settings or hovering the gear icon's tooltip.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ActionChip(
              label: Text(_germanLevel),
              tooltip: 'Your German level - tap to change',
              onPressed: _showSettingsSheet,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings (currently $_germanLevel, ${widget.themeMode.name} theme)',
            onPressed: _showSettingsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open file',
            onPressed: _isLoading ? null : _openFile,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Parsing $_loadingFileName…'),
                ],
              ),
            )
          : _document == null
              ? (_hasSeenOnboarding ? _buildEmptyState() : _buildOnboarding())
              : ReaderView(
                  document: _document!,
                  controller: _controller,
                  replacements: _replacements,
                  wordProgressRepository: _wordProgressRepository,
                  onWordLearned: _onWordLearned,
                  themePalette: widget.themePalette,
                  readerFont: widget.readerFont,
                  dictionaryRepository: _dictionaryRepository,
                ),
    );
  }

  /// Shown once, the very first time the app is opened (before there's
  /// anything in "recent documents" to show instead) - one short row per
  /// feature rather than a single wall of text, per how this was asked for.
  Widget _buildOnboarding() {
    final features = <(IconData, String, String)>[
      (
        Icons.folder_open,
        'Open a book',
        "Tap the folder icon up top to bring in a .txt, .docx, .epub, .pdf, or .html file - "
            "we'll turn it into a clean, comfy reading view.",
      ),
      (
        Icons.settings_outlined,
        'Pick your level',
        'Head into Settings and tell us your German level, A1 through C2 - '
            "we'll sprinkle in just the right amount of German as you read.",
      ),
      (
        Icons.touch_app_outlined,
        'Tap to toggle',
        "Spot a blue underlined word? That's German! Tap it to peek at the English, "
            'tap again to bring the German back.',
      ),
      (
        Icons.volume_up_outlined,
        'Hear it spoken',
        'Long-press any German word to hear it read aloud - handy for nailing the pronunciation.',
      ),
      (
        Icons.search,
        'Find anything',
        'Press Ctrl+F or tap the search icon to jump straight to any word or phrase.',
      ),
      (
        Icons.bookmarks_outlined,
        'Save your spot',
        'Drop as many bookmarks as you like, so you never lose your place.',
      ),
      (
        Icons.linear_scale,
        'Jump around',
        'Tap or drag the progress bar up top to zip to any part of the book instantly.',
      ),
      (
        Icons.celebration_outlined,
        'Level up!',
        "Learn every word at your level and we'll bump you up automatically - "
            'keep reading and watch your German grow.',
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Image.asset('assets/branding/logo.png', height: 96),
          const SizedBox(height: 16),
          Text('Willkommen! 🎉', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            "Here's the whirlwind tour - open a book and pick up a bit of German along the way.",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          for (final (icon, title, description) in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(description),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _showFirstLevelPickerThenOpenFile,
            icon: const Icon(Icons.folder_open),
            label: const Text("Let's open your first book!"),
          ),
        ],
      ),
    );
  }

  /// No document open yet. Shows the recent-documents list (SPEC.md section
  /// 7) when there is one, alongside the existing "open a file" action
  /// (AppBar folder icon, unaffected by this); falls back to the original
  /// plain instructional text when there's nothing recent yet.
  Widget _buildEmptyState() {
    if (_recentDocuments.isEmpty) {
      return Center(
        child: Text(
          _error ?? 'Open a .txt, .docx, .epub, .pdf, or .html file to start reading.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
        ],
        if (_bookmarkedInProgress.isNotEmpty) ...[
          Text('Continue reading', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final doc in _bookmarkedInProgress)
            _buildRecentDocumentCard(doc, leadingIcon: Icons.bookmark),
          const SizedBox(height: 16),
        ],
        Text('Recent', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final doc in _recentDocuments) _buildRecentDocumentCard(doc, leadingIcon: Icons.description_outlined),
      ],
    );
  }

  Widget _buildRecentDocumentCard(RecentDocument doc, {required IconData leadingIcon}) {
    return Card(
      child: ListTile(
        leading: Icon(leadingIcon),
        title: Text(doc.title),
        subtitle: Text(_formatLastOpened(doc.lastOpenedAt)),
        onTap: _isLoading ? null : () => _openPath(doc.filePath, fromRecent: true),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove from recent',
          onPressed: _isLoading ? null : () => _removeRecentDocument(doc.documentId),
        ),
      ),
    );
  }

  Future<void> _removeRecentDocument(String documentId) async {
    await _recentDocumentsRepository.remove(documentId);
    await _refreshRecentDocuments();
  }

  String _formatLastOpened(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}
