import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/main.dart';
import 'package:immersive_reader/models/bookmark.dart';
import 'package:immersive_reader/models/recent_document.dart';

/// pumpAndSettle can never finish while the indeterminate
/// CircularProgressIndicator HomePage shows during a real parse/vocab-load
/// is on screen - it perpetually schedules new frames. Must be called from
/// inside a tester.runAsync() block: `tester.pump(duration)` only advances
/// the fake animation clock, not real wall-clock time, so it never actually
/// gives the real background File-I/O/HTTP-fallback work a chance to
/// progress - a real Future.delayed does, since runAsync runs in the real
/// zone.
Future<void> _pumpUntilNotLoading(WidgetTester tester) async {
  await tester.pump();
  var attempts = 0;
  while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty && attempts < 50) {
    await Future.delayed(const Duration(milliseconds: 100));
    await tester.pump();
    attempts++;
  }
}

void main() {
  testWidgets('shows the plain empty-state message when there are no recent documents',
      (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.textContaining('Open a .txt'), findsOneWidget);
  });

  testWidgets('shows recent documents and resumes one on tap', (tester) async {
    late Directory dir;
    late File file;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('ir_recent_ui_test');
      file = File(p.join(dir.path, 'my_book.txt'));
      await file.writeAsString('This paragraph contains the marker ZzyxRecentTestMarker.');
    });

    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'recent_documents': jsonEncode([
        RecentDocument(
          documentId: 'my_book',
          title: 'my_book',
          filePath: file.path,
          format: 'txt',
          lastOpenedAt: DateTime.now(),
        ).toJson(),
      ]),
    });

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.text('my_book'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('my_book'));
      await _pumpUntilNotLoading(tester);
    });

    expect(find.textContaining('ZzyxRecentTestMarker'), findsOneWidget);

    await tester.runAsync(() async {
      dir.deleteSync(recursive: true);
    });
  });

  testWidgets('shows a back button once a document is open, and it returns to the recent list',
      (tester) async {
    late Directory dir;
    late File file;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('ir_back_button_test');
      file = File(p.join(dir.path, 'my_book.txt'));
      await file.writeAsString('This paragraph contains the marker ZzyxBackButtonMarker.');
    });

    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'recent_documents': jsonEncode([
        RecentDocument(
          documentId: 'my_book',
          title: 'my_book',
          filePath: file.path,
          format: 'txt',
          lastOpenedAt: DateTime.now(),
        ).toJson(),
      ]),
    });

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    // No back button before anything is open.
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('my_book'));
      await _pumpUntilNotLoading(tester);
    });

    expect(find.textContaining('ZzyxBackButtonMarker'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    // Back on the recent-documents list - the just-closed document is still
    // there (it was recorded when opened), and the back button is gone
    // again since nothing is open.
    expect(find.text('my_book'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.textContaining('ZzyxBackButtonMarker'), findsNothing);

    await tester.runAsync(() async {
      dir.deleteSync(recursive: true);
    });
  });

  testWidgets('deletes a recent document via its trailing delete button', (tester) async {
    late Directory dir;
    late File file;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('ir_delete_recent_test');
      file = File(p.join(dir.path, 'my_book.txt'));
      await file.writeAsString('This paragraph contains the marker ZzyxDeleteMarker.');
    });

    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'recent_documents': jsonEncode([
        RecentDocument(
          documentId: 'my_book',
          title: 'my_book',
          filePath: file.path,
          format: 'txt',
          lastOpenedAt: DateTime.now(),
        ).toJson(),
      ]),
    });

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.text('my_book'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
    });

    expect(find.text('my_book'), findsNothing);
    expect(find.textContaining('Open a .txt'), findsOneWidget);

    // The underlying file is untouched, only the recent-list entry is gone.
    await tester.runAsync(() async {
      expect(file.existsSync(), isTrue);
      dir.deleteSync(recursive: true);
    });
  });

  testWidgets('removes a recent entry whose file no longer exists, without crashing',
      (tester) async {
    final missingPath =
        p.join(Directory.systemTemp.path, 'ir_recent_ui_test_missing', 'gone.txt');
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'recent_documents': jsonEncode([
        RecentDocument(
          documentId: 'gone',
          title: 'gone',
          filePath: missingPath,
          format: 'txt',
          lastOpenedAt: DateTime.now(),
        ).toJson(),
      ]),
    });

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.text('gone'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('gone'));
      await tester.pumpAndSettle();
    });

    expect(tester.takeException(), isNull);
    expect(find.text('gone'), findsNothing);
    expect(find.textContaining('could not be found'), findsOneWidget);
  });

  testWidgets('shows a Continue reading section for a bookmarked, unfinished document',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'recent_documents': jsonEncode([
        RecentDocument(
          documentId: 'bookmarked_book',
          title: 'bookmarked_book',
          filePath: '/does/not/matter.txt',
          format: 'txt',
          lastOpenedAt: DateTime.now(),
          paragraphCount: 100,
        ).toJson(),
        RecentDocument(
          documentId: 'plain_book',
          title: 'plain_book',
          filePath: '/does/not/matter2.txt',
          format: 'txt',
          lastOpenedAt: DateTime.now(),
        ).toJson(),
      ]),
      'bookmarks_bookmarked_book': jsonEncode([Bookmark(id: '1', fraction: 0.2).toJson()]),
      'scroll_index_bookmarked_book': 20,
    });

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.text('Continue reading'), findsOneWidget);
    // Bookmarked-and-unfinished books appear in both sections (per design:
    // Continue reading is a highlighted subset, not a partition).
    expect(find.text('bookmarked_book'), findsNWidgets(2));
    expect(find.text('plain_book'), findsOneWidget);
  });

  testWidgets('does not show a Continue reading section when nothing recent has bookmarks',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'recent_documents': jsonEncode([
        RecentDocument(
          documentId: 'plain_book',
          title: 'plain_book',
          filePath: '/does/not/matter.txt',
          format: 'txt',
          lastOpenedAt: DateTime.now(),
        ).toJson(),
      ]),
    });

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.text('Continue reading'), findsNothing);
  });

  testWidgets('excludes a bookmarked document that is already finished from Continue reading',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'recent_documents': jsonEncode([
        RecentDocument(
          documentId: 'finished_book',
          title: 'finished_book',
          filePath: '/does/not/matter.txt',
          format: 'txt',
          lastOpenedAt: DateTime.now(),
          paragraphCount: 100,
        ).toJson(),
      ]),
      'bookmarks_finished_book': jsonEncode([Bookmark(id: '1', fraction: 0.99).toJson()]),
      'scroll_index_finished_book': 98,
    });

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.text('Continue reading'), findsNothing);
    expect(find.text('finished_book'), findsOneWidget); // still shown in Recent
  });
}
