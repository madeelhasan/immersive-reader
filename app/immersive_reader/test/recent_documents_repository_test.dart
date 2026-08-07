import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/library/recent_documents_repository.dart';
import 'package:immersive_reader/models/recent_document.dart';

RecentDocument _doc(String id, DateTime openedAt) => RecentDocument(
      documentId: id,
      title: id,
      filePath: '/path/to/$id.txt',
      format: 'txt',
      lastOpenedAt: openedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getRecent returns an empty list when nothing has ever been recorded', () async {
    final repo = RecentDocumentsRepository();
    expect(await repo.getRecent(), isEmpty);
  });

  test('recordOpened persists an entry retrievable via getRecent', () async {
    final repo = RecentDocumentsRepository();
    await repo.recordOpened(_doc('house', DateTime(2026, 1, 1)));

    final recent = await repo.getRecent();
    expect(recent.length, 1);
    expect(recent.first.documentId, 'house');
    expect(recent.first.filePath, '/path/to/house.txt');
    expect(recent.first.lastOpenedAt, DateTime(2026, 1, 1));
  });

  test('recordOpened orders entries newest-first', () async {
    final repo = RecentDocumentsRepository();
    await repo.recordOpened(_doc('first', DateTime(2026, 1, 1)));
    await repo.recordOpened(_doc('second', DateTime(2026, 1, 2)));
    await repo.recordOpened(_doc('third', DateTime(2026, 1, 3)));

    final recent = await repo.getRecent();
    expect(recent.map((d) => d.documentId).toList(), ['third', 'second', 'first']);
  });

  test('recordOpened on an already-present document moves it to front instead of duplicating', () async {
    final repo = RecentDocumentsRepository();
    await repo.recordOpened(_doc('a', DateTime(2026, 1, 1)));
    await repo.recordOpened(_doc('b', DateTime(2026, 1, 2)));
    await repo.recordOpened(_doc('a', DateTime(2026, 1, 3)));

    final recent = await repo.getRecent();
    expect(recent.length, 2);
    expect(recent.map((d) => d.documentId).toList(), ['a', 'b']);
    expect(recent.first.lastOpenedAt, DateTime(2026, 1, 3));
  });

  test('recordOpened caps the list at maxEntries, dropping the oldest', () async {
    final repo = RecentDocumentsRepository();
    for (var i = 0; i < RecentDocumentsRepository.maxEntries + 1; i++) {
      await repo.recordOpened(_doc('doc$i', DateTime(2026, 1, 1 + i)));
    }

    final recent = await repo.getRecent();
    expect(recent.length, RecentDocumentsRepository.maxEntries);
    expect(recent.first.documentId, 'doc${RecentDocumentsRepository.maxEntries}');
    expect(recent.map((d) => d.documentId), isNot(contains('doc0')));
  });

  test('remove deletes only the specified entry', () async {
    final repo = RecentDocumentsRepository();
    await repo.recordOpened(_doc('a', DateTime(2026, 1, 1)));
    await repo.recordOpened(_doc('b', DateTime(2026, 1, 2)));

    await repo.remove('a');

    final recent = await repo.getRecent();
    expect(recent.map((d) => d.documentId).toList(), ['b']);
  });

  test('remove on a non-existent id is a harmless no-op', () async {
    final repo = RecentDocumentsRepository();
    await repo.recordOpened(_doc('a', DateTime(2026, 1, 1)));

    await repo.remove('does-not-exist');

    final recent = await repo.getRecent();
    expect(recent.map((d) => d.documentId).toList(), ['a']);
  });

  test('paragraphCount round-trips through toJson/fromJson', () {
    final doc = RecentDocument(
      documentId: 'house',
      title: 'house',
      filePath: '/path/to/house.txt',
      format: 'txt',
      lastOpenedAt: DateTime(2026, 1, 1),
      paragraphCount: 250,
    );
    final decoded = RecentDocument.fromJson(doc.toJson());
    expect(decoded.paragraphCount, 250);
  });

  test('fromJson decodes a legacy entry with no paragraph_count field as null', () {
    final legacyJson = {
      'document_id': 'house',
      'title': 'house',
      'file_path': '/path/to/house.txt',
      'format': 'txt',
      'last_opened_at': DateTime(2026, 1, 1).toIso8601String(),
    };
    final decoded = RecentDocument.fromJson(legacyJson);
    expect(decoded.paragraphCount, isNull);
  });
}
