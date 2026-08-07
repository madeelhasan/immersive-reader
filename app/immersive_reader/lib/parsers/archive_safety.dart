import 'dart:convert';

import 'package:archive/archive.dart';

/// DOCX/EPUB are zip files, and `ArchiveFile.size` (an entry's *uncompressed*
/// size, read straight from the zip's central directory) is known without
/// decompressing anything. A single highly-compressible entry (e.g. one XML
/// file that's mostly repeated text) can unpack to hundreds of MB from a
/// file that's tiny on disk - a classic decompression-bomb shape. Checking
/// `.size` up front lets that be rejected instantly instead of actually
/// decompressing it, which would otherwise block the UI thread for however
/// long the real decompression takes.
const maxDecompressedEntryBytes = 50 * 1024 * 1024; // 50MB

class ArchiveEntryTooLargeException implements Exception {
  final String fileName;
  final int size;
  ArchiveEntryTooLargeException(this.fileName, this.size);

  @override
  String toString() =>
      'The file "$fileName" inside this document is too large to open '
      '($size bytes uncompressed) - this document may be corrupted.';
}

/// Decodes [file]'s content as UTF-8, refusing to decompress it at all if
/// its declared uncompressed size exceeds [maxDecompressedEntryBytes].
String decodeArchiveEntrySafely(ArchiveFile file) {
  if (file.size > maxDecompressedEntryBytes) {
    throw ArchiveEntryTooLargeException(file.name, file.size);
  }
  return utf8.decode(file.content as List<int>);
}
