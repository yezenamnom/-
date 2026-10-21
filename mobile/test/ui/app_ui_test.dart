import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  Future<TestApp> pump(WidgetTester tester, {String? locale}) async {
    late TestApp app;
    await tester.runAsync(() async => app = await TestApp.create(locale: locale));
    await tester.pumpWidget(app.widget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('home shows search, default shortcuts and quick actions (en)',
      (tester) async {
    await pump(tester, locale: 'en');
    expect(find.text('Search with DuckDuckGo or type address'), findsOneWidget);
    for (final s in ['YouTube', 'Twitch', 'TikTok', 'Rumble']) {
      expect(find.text(s), findsOneWidget);
    }
    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    // No ad space is reserved when no ad may be requested.
    expect(find.text('Ad'), findsNothing);
  });

  testWidgets('Arabic UI is right-to-left with translated shortcuts',
      (tester) async {
    await pump(tester, locale: 'ar');
    expect(find.text('يوتيوب'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('يوتيوب')));
    expect(dir, TextDirection.rtl);
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('German UI', (tester) async {
    await pump(tester, locale: 'de');
    expect(find.text('Lesezeichen'), findsOneWidget);
    expect(find.text('Einstellungen'), findsOneWidget);
  });

  testWidgets('private tab shows honest private-mode explanation, no shortcuts',
      (tester) async {
    final app = await pump(tester, locale: 'en');
    app.tabs.open(private: true);
    await tester.pumpAndSettle();
    expect(find.text("You're browsing privately"), findsOneWidget);
    expect(find.textContaining('does not hide you'), findsOneWidget);
    expect(find.text('YouTube'), findsNothing);
  });

  testWidgets('tab switcher: cards, close and close-all with confirmation',
      (tester) async {
    final app = await pump(tester, locale: 'en');
    app.tabs.open(url: Uri.parse('https://a.example.com/'))
      ..title = 'Alpha'
      ..url = null; // keep home page (no WebView in widget tests)
    app.tabs.open().title = 'Beta';
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tabs'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.byTooltip('Close tab').first);
    await tester.pumpAndSettle();
    expect(app.tabs.normalTabs.length, 1);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close all').last);
    await tester.pumpAndSettle();
    expect(find.text('Close all tabs?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(app.tabs.normalTabs.length, 1, reason: 'cancel keeps tabs');
  });

  testWidgets('add shortcut validates the address and keeps customisation',
      (tester) async {
    final app = await pump(tester, locale: 'en');
    await tester.tap(find.text('Add shortcut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'My site');
    await tester.enterText(find.byType(TextFormField).at(1), 'not a url');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid web address'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'example.org');
    await tester.tap(find.text('Save'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('My site'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(app.store.values['shortcuts.customized'], true);
  });

  testWidgets('settings: switching language applies immediately',
      (tester) async {
    final app = await pump(tester, locale: 'en');
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Block ads & trackers on websites'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('Block list version 1'), 200);
    expect(find.textContaining('Block list version 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Language'), -200);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(app.settings.locale?.languageCode, 'de');
    expect(find.text('Sprache'), findsOneWidget);
  });

  testWidgets('remove-ads page explains scope and hides purchase when unset',
      (tester) async {
    await pump(tester, locale: 'en');
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Remove app ads'), 300);
    await tester.tap(find.text('Remove app ads'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not a subscription to YouTube'), findsOneWidget);
    expect(find.text('Subscriptions are not set up in this version yet.'),
        findsOneWidget);
    expect(find.text('Restore purchases'), findsNothing);
  });

  testWidgets('large text scale does not overflow home', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late TestApp app;
    await tester.runAsync(() async => app = await TestApp.create(locale: 'ar'));
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: app.widget,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
