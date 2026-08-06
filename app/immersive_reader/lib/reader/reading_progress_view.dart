import 'package:flutter/material.dart';

import '../models/document_model.dart';

/// A dedicated page for seeing how far into a document the reader has
/// gotten and jumping elsewhere. Pushed from ReaderView's toolbar (and via
/// the Ctrl+G "go to page" shortcut, which skips this page and opens a
/// dialog directly instead). Purely presentational - it returns the target
/// scroll fraction via Navigator.pop rather than owning a ScrollController
/// itself, so ReaderView stays the single owner of actual scrolling.
class ReadingProgressView extends StatelessWidget {
  final String documentTitle;
  final int totalParagraphs;
  final double currentFraction;
  final List<ChapterMarker> chapters;

  const ReadingProgressView({
    super.key,
    required this.documentTitle,
    required this.totalParagraphs,
    required this.currentFraction,
    this.chapters = const [],
  });

  double _startFraction(ChapterMarker chapter) {
    if (totalParagraphs == 0) return 0.0;
    return chapter.paragraphIndex / totalParagraphs;
  }

  int get _currentChapterIndex {
    var current = 0;
    for (var i = 0; i < chapters.length; i++) {
      if (_startFraction(chapters[i]) <= currentFraction) current = i;
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    final percent = (currentFraction * 100).round();
    final progressHeader = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$percent% read · ${100 - percent}% left'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: currentFraction),
          const SizedBox(height: 16),
          Slider(
            min: 0.0,
            max: 1.0,
            value: currentFraction,
            divisions: 100,
            onChanged: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(documentTitle)),
      body: chapters.isEmpty
          ? progressHeader
          : Column(
              children: [
                progressHeader,
                Expanded(
                  child: ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      final Icon leading;
                      if (index < _currentChapterIndex) {
                        leading = const Icon(Icons.check_circle, color: Colors.green);
                      } else if (index == _currentChapterIndex) {
                        leading = const Icon(Icons.radio_button_checked, color: Colors.blue);
                      } else {
                        leading = const Icon(Icons.circle_outlined);
                      }
                      return ListTile(
                        leading: leading,
                        title: Text(chapter.title),
                        onTap: () => Navigator.pop(context, _startFraction(chapter)),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
