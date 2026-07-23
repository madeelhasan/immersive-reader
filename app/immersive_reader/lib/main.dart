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

class ImmersiveReaderApp extends StatelessWidget {
  const ImmersiveReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Immersive Reader',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_document?.title ?? 'Immersive Reader'),
        actions: [
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
