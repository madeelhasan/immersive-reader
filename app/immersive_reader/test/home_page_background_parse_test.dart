import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/main.dart';
import 'package:immersive_reader/models/recent_document.dart';

// Regression coverage for a real reported freeze: parsing a large PDF is
// several seconds of genuinely synchronous CPU work (PdfTextExtractor
// walking every page) - run on the main isolate, that blocks the whole UI,
// including the loading spinner's own animation, for the entire duration.
// _openPath now runs the actual parse via compute() on a background
// isolate instead (see lib/parsers/background_parse.dart) - this exercises
// that real path end-to-end against the real PDF fixture, not just a
// synthetic in-memory DocumentModel.
Future<void> _pumpUntilNotLoading(WidgetTester tester) async {
  await tester.pump();
  var attempts = 0;
  while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty && attempts < 200) {
    await Future.delayed(const Duration(milliseconds: 100));
    await tester.pump();
    attempts++;
  }
}

void main() {
  testWidgets('opening a real large PDF from Recent parses on a background isolate and shows its content',
      (tester) async {
    const pdfPath = 'test/fixtures/A Court of Thorns and Roses - PDF Room.pdf';
    if (!File(pdfPath).existsSync()) {
      // Fixture is git-ignored (copyright) - skip gracefully where absent.
      return;
    }

    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'recent_documents': jsonEncode([
        RecentDocument(
          documentId: 'pdf_book',
          title: 'pdf_book',
          filePath: pdfPath,
          format: 'pdf',
          lastOpenedAt: DateTime.now(),
        ).toJson(),
      ]),
    });

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.text('pdf_book'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('pdf_book'));
      await _pumpUntilNotLoading(tester);
    });

    // ReaderView renders each token as its own Text widget, so a
    // multi-word phrase never matches a single widget's text - check a
    // single word known to be in the fixture instead (see its snippet in
    // fixtures_check_test.dart: "...go Under the Mountain for me...").
    expect(find.textContaining('Mountain'), findsWidgets);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
