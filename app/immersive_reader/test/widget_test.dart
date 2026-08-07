import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/main.dart';

void main() {
  testWidgets('App starts on the empty-library home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ImmersiveReaderApp());

    expect(find.text('Immersive Reader'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });

  testWidgets('shows the first-launch onboarding screen when nothing has been seen or opened yet',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Willkommen'), findsOneWidget);
    expect(find.text('Pick your level'), findsOneWidget);

    // The CTA button sits below the feature list, past what a plain
    // ListView builds eagerly - scroll it into the cached/visible range.
    await tester.scrollUntilVisible(find.text("Let's open your first book!"), 300);
    expect(find.text("Let's open your first book!"), findsOneWidget);
  });

  testWidgets('onboarding does not reappear once dismissed', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Willkommen'), findsNothing);
    expect(find.textContaining('Open a .txt'), findsOneWidget);
  });

  testWidgets('German level selector defaults to A1 and can be changed via Settings',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    // A1 is the default level, shown selected among the radio options.
    expect(find.text('A1'), findsOneWidget);

    await tester.tap(find.text('B1'));
    await tester.pumpAndSettle();

    // The sheet stays open after selecting a level (no auto-dismiss) -
    // check the change stuck without closing/reopening, since the modal
    // barrier behind an already-open sheet would swallow a second tap on
    // the AppBar's settings icon rather than reaching it.
    final radio = tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
    expect(radio.groupValue, 'B1');
  });

  testWidgets('Settings sheet separates App and Reading & Vocabulary sections',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('APP'), findsOneWidget);
    expect(find.text('READING & VOCABULARY'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    // All six CEFR levels should be offered.
    for (final level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
      expect(find.text(level), findsOneWidget);
    }
  });
}
