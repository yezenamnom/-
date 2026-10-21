// Renders app screens to PNG with real fonts, for documentation only.
// These are Flutter test-engine renders, NOT device screenshots (no WebView,
// no ads, no platform UI). Run:
//   flutter test test_screenshots --update-goldens
// Output: test_screenshots/out/*.png (copied to docs/screenshots/).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

Future<void> loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter';
  final text = FontLoader('Roboto')
    ..addFont(_bytes('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
    ..addFont(_bytes('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'));
  await text.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(_bytes(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<ByteData> _bytes(String path) async =>
    ByteData.sublistView(File(path).readAsBytesSync());

void main() {
  setUpAll(loadFonts);

  Future<TestApp> shot(
    WidgetTester tester,
    String name, {
    required String locale,
    String theme = 'light',
    Future<void> Function(WidgetTester, TestApp)? before,
  }) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late TestApp app;
    await tester.runAsync(() async {
      app = await TestApp.create(locale: locale);
      app.store.values['ui.theme'] = theme;
    });
    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    if (before != null) await before(tester, app);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    return app;
  }

  testWidgets('home ar', (t) => shot(t, 'home_ar', locale: 'ar'));
  testWidgets('home en dark', (t) => shot(t, 'home_en_dark', locale: 'en', theme: 'dark'));
  testWidgets('home de', (t) => shot(t, 'home_de', locale: 'de'));
  testWidgets('private ar', (t) => shot(t, 'private_ar', locale: 'ar',
      before: (t, app) async => app.tabs.open(private: true)));
  testWidgets('tabs ar', (t) => shot(t, 'tabs_ar', locale: 'ar', before: (t, app) async {
        for (final title in ['يوتيوب', 'أخبار', 'ويكيبيديا']) {
          app.tabs.open().title = title;
        }
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('التبويبات'));
      }));
  testWidgets('settings ar', (t) => shot(t, 'settings_ar', locale: 'ar',
      before: (t, app) async => t.tap(find.text('الإعدادات'))));
  testWidgets('menu en', (t) => shot(t, 'menu_en', locale: 'en',
      before: (t, app) async => t.tap(find.byTooltip('Menu'))));
}
