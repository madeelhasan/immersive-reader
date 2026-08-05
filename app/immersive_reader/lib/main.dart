import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models/document_model.dart';
import 'parsers/parser_registry.dart';
import 'reader/reader_controller.dart';
import 'reader/reader_view.dart';

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

  void _cycleThemeMode() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
        ThemeMode.system => ThemeMode.light,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Immersive Reader',
      theme: ThemeData(primarySwatch: Colors.blue),
      darkTheme: ThemeData.dark(),
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
  final ReaderController _controller = ReaderController();
  DocumentModel? _document;
  String? _error;

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx', 'epub', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    try {
      final parser = ParserRegistry.forFileName(path);
      final document = await parser.parse(File(path));
      final hasText = document.paragraphs
          .any((para) => para.sentences.any((s) => s.tokens.isNotEmpty));

      setState(() {
        if (hasText) {
          _document = document;
          _error = null;
        } else {
          _document = null;
          _error = 'No text could be extracted from this file. '
              'If it\'s a PDF, it may be a scanned/image-based document '
              'with no selectable text layer.';
        }
      });
    } catch (e) {
      setState(() {
        _document = null;
        _error = 'Could not open file: $e';
      });
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
          IconButton(
            icon: Icon(_themeIcon),
            tooltip: 'Toggle light/dark theme (currently ${widget.themeMode.name})',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open file',
            onPressed: _openFile,
          ),
        ],
      ),
      body: _document == null
          ? Center(
              child: Text(
                _error ?? 'Open a .txt, .docx, .epub, or .pdf file to start reading.',
              ),
            )
          : ReaderView(document: _document!, controller: _controller),
    );
  }
}
