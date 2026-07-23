import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/pdf_parser.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('PdfParser extracts text drawn onto a real PDF', () async {
    final doc = PdfDocument();
    final page = doc.pages.add();
    page.graphics.drawString(
      'Hello world from a generated PDF.',
      PdfStandardFont(PdfFontFamily.helvetica, 14),
    );
    final bytes = await doc.save();
    doc.dispose();

    final dir = Directory.systemTemp.createTempSync('ir_pdf_smoke');
    final file = File(p.join(dir.path, 'sample.pdf'));
    file.writeAsBytesSync(bytes);

    final parsed = await PdfParser().parse(file);
    final text = parsed.paragraphs
        .expand((para) => para.sentences)
        .expand((s) => s.tokens)
        .map((t) => t.text)
        .join(' ');
    expect(text, contains('Hello'));

    dir.deleteSync(recursive: true);
  });
}
