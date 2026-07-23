import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/main.dart';

void main() {
  testWidgets('App starts on the empty-library home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ImmersiveReaderApp());

    expect(find.text('Immersive Reader'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });
}
