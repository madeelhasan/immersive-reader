import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/library/reading_progress_lookup.dart';
import 'package:immersive_reader/models/bookmark.dart';
import 'package:immersive_reader/models/recent_document.dart';

RecentDocument _doc({int? paragraphCount}) => RecentDocument(
      documentId: 'house',
      title: 'house',
      filePath: '/path/to/house.txt',
      format: 'txt',
      lastOpenedAt: DateTime(2026, 1, 1),
      paragraphCount: paragraphCount,
    );

Map<String, Object> _prefsWith({
  List<Bookmark>? bookmarks,
  int? scrollIndex,
  String documentId = 'house',
}) {
  final values = <String, Object>{};
  if (bookmarks != null) {
    values['bookmarks_$documentId'] = jsonEncode(bookmarks.map((b) => b.toJson()).toList());
  }
  if (scrollIndex != null) {
    values['scroll_index_$documentId'] = scrollIndex;
  }
  return values;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hasBookmarks', () {
    test('false when nothing is stored for the document', () async {
      SharedPreferences.setMockInitialValues({});
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.hasBookmarks('house'), isFalse);
    });

    test('false when the stored bookmark list is empty', () async {
      SharedPreferences.setMockInitialValues(_prefsWith(bookmarks: []));
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.hasBookmarks('house'), isFalse);
    });

    test('true when at least one bookmark is stored', () async {
      SharedPreferences.setMockInitialValues(
        _prefsWith(bookmarks: [Bookmark(id: '1', fraction: 0.2)]),
      );
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.hasBookmarks('house'), isTrue);
    });
  });

  group('isCompleted', () {
    test('false when paragraphCount was never recorded (legacy entry)', () async {
      SharedPreferences.setMockInitialValues(_prefsWith(scrollIndex: 999));
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.isCompleted(_doc(paragraphCount: null)), isFalse);
    });

    test('false when no scroll position has been saved yet', () async {
      SharedPreferences.setMockInitialValues({});
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.isCompleted(_doc(paragraphCount: 100)), isFalse);
    });

    test('false when the reader is well short of the end', () async {
      SharedPreferences.setMockInitialValues(_prefsWith(scrollIndex: 10));
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.isCompleted(_doc(paragraphCount: 100)), isFalse);
    });

    test('true once scroll position reaches the completion threshold', () async {
      SharedPreferences.setMockInitialValues(_prefsWith(scrollIndex: 95));
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      // index 95 of 100 paragraphs -> 95/99 ≈ 0.96, past the 0.95 threshold.
      expect(lookup.isCompleted(_doc(paragraphCount: 100)), isTrue);
    });
  });

  group('isInProgress', () {
    test('true when bookmarked and not completed', () async {
      SharedPreferences.setMockInitialValues(_prefsWith(
        bookmarks: [Bookmark(id: '1', fraction: 0.2)],
        scrollIndex: 20,
      ));
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.isInProgress(_doc(paragraphCount: 100)), isTrue);
    });

    test('false when bookmarked but completed', () async {
      SharedPreferences.setMockInitialValues(_prefsWith(
        bookmarks: [Bookmark(id: '1', fraction: 0.99)],
        scrollIndex: 98,
      ));
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.isInProgress(_doc(paragraphCount: 100)), isFalse);
    });

    test('false when not bookmarked, regardless of progress', () async {
      SharedPreferences.setMockInitialValues(_prefsWith(scrollIndex: 20));
      final lookup = ReadingProgressLookup(await SharedPreferences.getInstance());
      expect(lookup.isInProgress(_doc(paragraphCount: 100)), isFalse);
    });
  });
}
