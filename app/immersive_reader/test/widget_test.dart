import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/main.dart';

void main() {
  testWidgets('App starts on the empty-library home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ImmersiveReaderApp());

    expect(find.text('Immersive Reader'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });

  testWidgets('German level selector defaults to A1 and can be changed', (WidgetTester tester) async {
    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pump();

    expect(find.text('A1'), findsOneWidget);

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B1').last);
    await tester.pumpAndSettle();

    expect(find.text('B1'), findsOneWidget);
    expect(find.text('A1'), findsNothing);
  });
}
