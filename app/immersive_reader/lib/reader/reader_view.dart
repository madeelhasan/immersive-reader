import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _debounceDuration = Duration(milliseconds: 400);
  static const _minFontSize = 10.0;
  static const _maxFontSize = 32.0;

  late ScrollController _scrollController;
  Timer? _saveDebounce;
  double _fontSize = 16.0;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                    children: sentence.tokens.map((token) {
                      return Text('${token.text} ', style: TextStyle(fontSize: _fontSize));
                    }).toList(),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
