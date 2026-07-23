import 'package:flutter/material.dart';
import '../models/document_model.dart';
import 'reader_controller.dart';

class ReaderView extends StatefulWidget {
  final DocumentModel document;
  final ReaderController controller;

  const ReaderView({super.key, required this.document, required this.controller});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        widget.controller.updateScrollPosition(_scrollController.position.pixels);
      });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.document.paragraphs.length,
      itemBuilder: (context, index) {
        final paragraph = widget.document.paragraphs[index];
        return Column(
          children: paragraph.sentences.map((sentence) {
            return Wrap(
              children: sentence.tokens.map((token) {
                return Text('${token.text} ');
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }
}
