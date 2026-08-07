import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/storage/document_cache_repository.dart';
import 'package:immersive_reader/storage/local_db.dart';

DocumentModel _buildDocument(String id) {
  return DocumentModel(
    document_id: id,
    title: 'Test Doc',
    paragraphs: [
      ParagraphModel(
        paragraph_id: 'p0',
        sentences: [
          SentenceModel(
            sentence_id: 's0',
            tokens: [
              Token(tokenId: 't0', text: 'Hello', isWord: true, positionIndex: 0),
              Token(tokenId: 't1', text: 'world', isWord: true, positionIndex: 1),
            ],
          ),
        ],
      ),
    ],
    chapters: [ChapterMarker(title: 'Chapter 1', paragraphIndex: 0)],
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDb db;
  late DocumentCacheRepository repo;
  late Directory tempDir;

  setUp(() async {
    db = LocalDb();
    await db.init(path: inMemoryDatabasePath);
    repo = DocumentCacheRepository(db);
    tempDir = await Directory.systemTemp.createTemp('doc_cache_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('DocumentModel round-trips through toJson/fromJson unchanged', () {
    final original = _buildDocument('doc1');
    final restored = DocumentModel.fromJson(original.toJson());

    expect(restored.document_id, original.document_id);
    expect(restored.title, original.title);
    expect(restored.chapters.single.title, 'Chapter 1');
    expect(restored.paragraphs.single.sentences.single.tokens.map((t) => t.text), ['Hello', 'world']);
  });

  test('a cache miss for a file that was never cached returns null', () async {
    final file = File('${tempDir.path}/never_cached.txt')..writeAsStringSync('content');
    expect(await repo.get(file.path), isNull);
  });

  test('put then get returns an equivalent document for an unchanged file', () async {
    final file = File('${tempDir.path}/doc.txt')..writeAsStringSync('original content');
    final document = _buildDocument('doc1');

    await repo.put(file.path, document);
    final cached = await repo.get(file.path);

    expect(cached, isNotNull);
    expect(cached!.document_id, 'doc1');
    expect(cached.paragraphs.single.sentences.single.tokens.first.text, 'Hello');
  });

  test('a cache entry is invalidated once the source file changes', () async {
    final file = File('${tempDir.path}/doc.txt')..writeAsStringSync('original content');
    await repo.put(file.path, _buildDocument('doc1'));

    // Modify the file - different size, and sqflite integer columns store
    // millisecond precision, so bump the clock forward enough to guarantee
    // a different mtime even on filesystems with coarser timestamp granularity.
    final newModified = DateTime.now().add(const Duration(seconds: 2));
    file.writeAsStringSync('original content, but now longer');
    file.setLastModifiedSync(newModified);

    expect(await repo.get(file.path), isNull);
  });

  test('returns null (not an exception) if the source file has been deleted', () async {
    final file = File('${tempDir.path}/doc.txt')..writeAsStringSync('content');
    await repo.put(file.path, _buildDocument('doc1'));
    await file.delete();

    expect(await repo.get(file.path), isNull);
  });
}
