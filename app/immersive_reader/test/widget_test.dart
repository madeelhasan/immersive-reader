import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/main.dart';
import 'package:immersive_reader/theme/reader_font.dart';
import 'package:immersive_reader/theme/reader_theme_palette.dart';

void main() {
  testWidgets('App starts on the empty-library home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ImmersiveReaderApp());

    expect(find.text('Lesefluss'), findsOneWidget);
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

  testWidgets('the current German level is always visible in the AppBar', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    // A1 is the default - previously only discoverable via the settings
    // gear's tooltip or by opening Settings.
    expect(find.text('A1'), findsOneWidget);
  });

  testWidgets('first-time import prompts for a starting level before opening the file picker',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text("Let's open your first book!"), 300);
    await tester.tap(find.text("Let's open your first book!"));
    await tester.pumpAndSettle();

    expect(find.text("What's your German level?"), findsOneWidget);
    // A1 (the current default) also appears in the always-visible AppBar
    // chip behind the dialog.
    expect(find.text('A1'), findsNWidgets(2));
    for (final level in ['A2', 'B1', 'B2', 'C1', 'C2']) {
      expect(find.text(level), findsOneWidget);
    }

    await tester.tap(find.text('B2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('german_level'), 'B2');
    expect(find.text('B2'), findsOneWidget); // now shown in the AppBar chip
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
    // A1 is the default level - shown both in the always-visible AppBar
    // chip and selected among the settings sheet's radio options.
    expect(find.text('A1'), findsNWidgets(2));

    // The font picker section pushes the CEFR level list below the fold -
    // scroll it into view before tapping (plain tap() doesn't auto-scroll).
    await tester.scrollUntilVisible(find.text('B1'), 200);
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
    // All six CEFR levels should be offered. A1 (the default/current
    // level) also appears in the always-visible AppBar chip.
    expect(find.text('A1'), findsNWidgets(2));
    for (final level in ['A2', 'B1', 'B2', 'C1', 'C2']) {
      expect(find.text(level), findsOneWidget);
    }
  });

  testWidgets('changing the theme persists it, and a fresh launch restores it',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Defaults to "Match system" - one tap on the Theme tile cycles to Light.
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');

    // Close the sheet before relaunching - a still-open modal's barrier
    // would otherwise swallow a tap aimed at the AppBar underneath it.
    await tester.tap(find.byType(ModalBarrier).last);
    await tester.pumpAndSettle();

    // A fresh app instance (simulating a relaunch) should restore it rather
    // than default back to "Match system" - a distinct Key is required
    // here, not just a second identical `const ImmersiveReaderApp()`: same
    // type + same (null) key means the element tree just updates the
    // existing State rather than disposing and recreating it, so initState
    // (and the restore logic in it) would never run a second time.
    await tester.pumpWidget(ImmersiveReaderApp(key: UniqueKey()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
  });

  testWidgets('Settings sheet offers all four theme palettes, with high contrast noted',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    for (final label in ['Warm', 'Sage', 'Ocean', 'High Contrast']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('larger minimum text'), findsOneWidget);
  });

  testWidgets('selecting a theme palette persists it, and a fresh launch restores it',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_palette'), 'ocean');

    await tester.tap(find.byType(ModalBarrier).last);
    await tester.pumpAndSettle();

    await tester.pumpWidget(ImmersiveReaderApp(key: UniqueKey()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final radio =
        tester.widget<RadioGroup<ReaderThemePalette>>(find.byType(RadioGroup<ReaderThemePalette>));
    expect(radio.groupValue, ReaderThemePalette.ocean);
  });

  testWidgets('Settings sheet offers all five reader fonts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    for (final label in ['Georgia', 'Cambria', 'Constantia', 'Calibri', 'Segoe UI']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('selecting a reader font persists it, and a fresh launch restores it',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const ImmersiveReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Calibri'), 200);
    await tester.tap(find.text('Calibri'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('reader_font'), 'calibri');

    await tester.tap(find.byType(ModalBarrier).last);
    await tester.pumpAndSettle();

    await tester.pumpWidget(ImmersiveReaderApp(key: UniqueKey()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final radio = tester.widget<RadioGroup<ReaderFont>>(find.byType(RadioGroup<ReaderFont>));
    expect(radio.groupValue, ReaderFont.calibri);
  });
}
