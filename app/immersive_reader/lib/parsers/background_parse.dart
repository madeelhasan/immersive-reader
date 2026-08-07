import 'dart:io';

import '../models/document_model.dart';
import 'parser_registry.dart';

/// Runs an actual parse (file I/O + tokenization) off the main isolate via
/// `compute()`. A top-level function, not a method, because `compute()`
/// requires its callback to be safely sendable to a spawned isolate - a
/// closure capturing State/BuildContext wouldn't be. Measured directly
/// against the PDF test fixture: parsing alone can take several seconds of
/// genuinely synchronous CPU work (PdfTextExtractor walking every page) -
/// on the main isolate that blocks the whole UI, including the loading
/// spinner's own animation, for that entire duration. Verified this parser
/// (syncfusion_flutter_pdf's text extraction, despite the package name,
/// does pure computation with no dart:ui/platform-channel dependency) runs
/// cleanly in a background isolate before relying on this.
Future<DocumentModel> parseDocumentInBackground(String path) {
  return ParserRegistry.forFileName(path).parse(File(path));
}
