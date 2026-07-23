import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/parsers/parser_registry.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';

void main() {
  testWidgets('ReaderView renders the large PDF fixture without hanging',
      (tester) async {
    // Real file I/O + PDF parsing must run outside the fake-async zone
    // testWidgets uses, or the awaited Future never resolves.
    final document = await tester.runAsync(() async {
      final file =
          File('test/fixtures/A Court of Thorns and Roses - PDF Room.pdf');
      return ParserRegistry.forFileName(file.path).parse(file);
    });

    await tester.pumpWidget(MaterialApp(
      home: ReaderView(
        document: document as DocumentModel,
        controller: ReaderController(),
      ),
    ));
    await tester.pump();

    expect(find.byType(ReaderView), findsOneWidget);
    expect(find.textContaining('Josh'), findsOneWidget);
  });
}
