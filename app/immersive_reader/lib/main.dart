import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/document_model.dart';
import 'models/token.dart';
import 'parsers/parser_registry.dart';
import 'progress/local_user_id.dart';
import 'progress/word_progress_repository.dart';
import 'reader/reader_controller.dart';
import 'reader/reader_view.dart';
import 'replacement/replacement_engine.dart';
import 'storage/local_db.dart';
import 'vocabulary/vocabulary_repository.dart';

void main() {
  runApp(const ImmersiveReaderApp());
}

class ImmersiveReaderApp extends StatefulWidget {
  const ImmersiveReaderApp({super.key});

  @override
  State<ImmersiveReaderApp> createState() => _ImmersiveReaderAppState();
}

class _ImmersiveReaderAppState extends State<ImmersiveReaderApp> {
  ThemeMode _themeMode = ThemeMode.system;

  // A warm, book-like palette instead of stock Material blue/white - cream
  // "paper" in light mode, soft warm charcoal (not pure black) in dark
  // mode, both easier on the eyes for long-form reading than high-contrast
  // pure white/black. Georgia ships with Windows, so this needs no new
  // font asset or runtime download, matching the app's offline-first bent.
  static const _readingFontFamily = 'Georgia';
  static const _lightBackground = Color(0xFFFBF6EC);
  static const _lightText = Color(0xFF2B2620);
  static const _lightAccent = Color(0xFF8B5E34);
  static const _darkBackground = Color(0xFF1E1B16);
  static const _darkText = Color(0xFFEDE6D9);
  static const _darkAccent = Color(0xFFD9A566);

  void _cycleThemeMode() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
        ThemeMode.system => ThemeMode.light,
      };
    });
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color text,
    required Color accent,
  }) {
    final base = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(surface: background),
      appBarTheme: AppBarTheme(backgroundColor: background, foregroundColor: text, elevation: 0),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: _readingFontFamily, bodyColor: text, displayColor: text),
      primaryTextTheme:
          base.primaryTextTheme.apply(fontFamily: _readingFontFamily, bodyColor: text, displayColor: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Immersive Reader',
      theme: _buildTheme(
        brightness: Brightness.light,
        background: _lightBackground,
        text: _lightText,
        accent: _lightAccent,
      ),
      darkTheme: _buildTheme(
        brightness: Brightness.dark,
        background: _darkBackground,
        text: _darkText,
        accent: _darkAccent,
      ),
      themeMode: _themeMode,
      home: HomePage(themeMode: _themeMode, onToggleTheme: _cycleThemeMode),
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const HomePage({super.key, required this.themeMode, required this.onToggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _germanLevelPrefsKey = 'german_level';

  final ReaderController _controller = ReaderController();
  final VocabularyRepository _vocabularyRepository = VocabularyRepository();
  DocumentModel? _document;
  List<Token> _tokens = [];
  Map<String, String> _replacements = {};
  String? _error;
  String _germanLevel = 'A1';
  String? _loadingFileName;
  WordProgressRepository? _wordProgressRepository;

  bool get _isLoading => _loadingFileName != null;

  @override
  void initState() {
    super.initState();
    _restoreGermanLevel();
    _initWordProgressRepository();
  }

  /// LocalDb.init() is async, so the repository isn't available on the
  /// very first frame - ReaderView treats a null wordProgressRepository as
  /// "don't track events yet", which is fine for the brief window before
  /// this completes. Also swallows failures (e.g. no sqflite platform
  /// channel in a plain widget test) the same way VocabularyRepository
  /// falls back rather than crashing app startup over progress tracking.
  Future<void> _initWordProgressRepository() async {
    final WordProgressRepository repository;
    try {
      final db = LocalDb();
      await db.init();
      final userId = await getOrCreateLocalUserId();
      repository = WordProgressRepository(db, userId);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _wordProgressRepository = repository;
    });
  }

  Future<void> _restoreGermanLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_germanLevelPrefsKey);
    if (saved == null || !ReplacementEngine.levelOrder.contains(saved)) return;
    setState(() => _germanLevel = saved);
    _recomputeReplacements();
  }

  Future<void> _setGermanLevel(String level) async {
    setState(() => _germanLevel = level);
    _recomputeReplacements();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_germanLevelPrefsKey, level);
  }

  /// Re-rolls replacements for the currently open document against the
  /// current _germanLevel. A no-op if no document is open yet - _openFile
  /// picks up _germanLevel directly once one is.
  Future<void> _recomputeReplacements() async {
    if (_document == null || _tokens.isEmpty) return;
    final vocabulary = await _vocabularyRepository.load();
    final replacements = ReplacementEngine().selectReplacements(
      _tokens,
      vocabulary,
      germanLevel: _germanLevel,
    );
    if (!mounted) return;
    setState(() => _replacements = replacements);
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx', 'epub', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _loadingFileName = p.basename(path));

    try {
      final parser = ParserRegistry.forFileName(path);
      final document = await parser.parse(File(path));
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

      final vocabulary = await _vocabularyRepository.load();
      final replacements = ReplacementEngine().selectReplacements(
        tokens,
        vocabulary,
        germanLevel: _germanLevel,
      );

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
        _error = 'Could not open file: $e';
      });
    } finally {
      setState(() => _loadingFileName = null);
    }
  }

  IconData get _themeIcon => switch (widget.themeMode) {
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.system => Icons.brightness_auto,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_document?.title ?? 'Immersive Reader'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'German level (currently $_germanLevel)',
            initialValue: _germanLevel,
            onSelected: _setGermanLevel,
            itemBuilder: (context) => ReplacementEngine.levelOrder
                .map((level) => PopupMenuItem(value: level, child: Text(level)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(_germanLevel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_themeIcon),
            tooltip: 'Toggle light/dark theme (currently ${widget.themeMode.name})',
            onPressed: widget.onToggleTheme,
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
              ? Center(
                  child: Text(
                    _error ?? 'Open a .txt, .docx, .epub, or .pdf file to start reading.',
                  ),
                )
              : ReaderView(
                  document: _document!,
                  controller: _controller,
                  replacements: _replacements,
                  wordProgressRepository: _wordProgressRepository,
                ),
    );
  }
}
