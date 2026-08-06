import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/reader/reading_progress_view.dart';

void main() {
  testWidgets('shows percent read/left and a progress bar', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ReadingProgressView(
        documentTitle: 'Test Book',
        totalParagraphs: 100,
        currentFraction: 0.62,
      ),
    ));

    expect(find.text('Test Book'), findsOneWidget);
    expect(find.text('62% read · 38% left'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('renders with no chapter list when chapters is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ReadingProgressView(
        documentTitle: 'Test Book',
        totalParagraphs: 100,
        currentFraction: 0.0,
      ),
    ));

    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('marks chapters read/current/unread based on currentFraction', (tester) async {
    final chapters = [
      ChapterMarker(title: 'Chapter 1', paragraphIndex: 0),
      ChapterMarker(title: 'Chapter 2', paragraphIndex: 25),
      ChapterMarker(title: 'Chapter 3', paragraphIndex: 75),
    ];

    await tester.pumpWidget(MaterialApp(
      home: ReadingProgressView(
        documentTitle: 'Test Book',
        totalParagraphs: 100,
        currentFraction: 0.5, // between chapter 2 (0.25) and chapter 3 (0.75)
        chapters: chapters,
      ),
    ));

    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Chapter 2'), findsOneWidget);
    expect(find.text('Chapter 3'), findsOneWidget);

    // Chapter 1: read. Chapter 2: current. Chapter 3: unread.
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons[0].icon, Icons.check_circle);
    expect(icons[1].icon, Icons.radio_button_checked);
    expect(icons[2].icon, Icons.circle_outlined);
  });

  testWidgets('tapping a chapter pops its start fraction', (tester) async {
    final chapters = [
      ChapterMarker(title: 'Chapter 1', paragraphIndex: 0),
      ChapterMarker(title: 'Chapter 2', paragraphIndex: 50),
    ];

    double? poppedValue;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            poppedValue = await Navigator.push<double>(
              context,
              MaterialPageRoute(
                builder: (_) => ReadingProgressView(
                  documentTitle: 'Test Book',
                  totalParagraphs: 100,
                  currentFraction: 0.0,
                  chapters: chapters,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Chapter 2'));
    await tester.pumpAndSettle();

    expect(poppedValue, 0.5); // paragraphIndex 50 / totalParagraphs 100
  });

  testWidgets('slider drag pops the new fraction', (tester) async {
    double? poppedValue;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            poppedValue = await Navigator.push<double>(
              context,
              MaterialPageRoute(
                builder: (_) => const ReadingProgressView(
                  documentTitle: 'Test Book',
                  totalParagraphs: 100,
                  currentFraction: 0.2,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(poppedValue, isNotNull);
    expect(poppedValue, greaterThan(0.2));
  });
}
