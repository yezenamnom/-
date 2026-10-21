import 'package:flutter_test/flutter_test.dart';
import 'package:vela_browser/core/search_engines.dart';
import 'package:vela_browser/core/url_input.dart';
import 'package:vela_browser/core/url_safety.dart';

void main() {
  final engine = searchEngineById('duckduckgo');

  Uri nav(String s) => (resolveInput(s, engine) as NavigateTo).uri;
  SearchFor search(String s) => resolveInput(s, engine) as SearchFor;

  group('resolveInput', () {
    test('empty input', () {
      expect(resolveInput('   ', engine), isNull);
    });

    test('bare domains default to https', () {
      expect(nav('example.com').toString(), 'https://example.com');
      expect(nav('m.youtube.com/watch?v=1').toString(),
          'https://m.youtube.com/watch?v=1');
      expect(nav('EXAMPLE.de').host, 'example.de');
    });

    test('explicit http and https are respected', () {
      expect(nav('http://example.com').scheme, 'http');
      expect(nav('https://example.com/a b'.replaceAll(' ', '%20')).scheme,
          'https');
    });

    test('host:port and localhost', () {
      expect(nav('localhost:8080').toString(), 'http://localhost:8080');
      expect(nav('192.168.1.1').toString(), 'http://192.168.1.1');
      expect(nav('example.com:8443/x').toString(), 'https://example.com:8443/x');
    });

    test('words and phrases become searches', () {
      final s = search('how to cook rice');
      expect(s.uri.host, 'duckduckgo.com');
      expect(s.uri.queryParameters['q'], 'how to cook rice');
      expect(search('flutter').query, 'flutter');
      expect(search('مرحبا بالعالم').uri.queryParameters['q'], 'مرحبا بالعالم');
      expect(search('999.999.1.1').query, '999.999.1.1');
    });

    test('dangerous schemes are never navigations', () {
      for (final s in [
        'javascript:alert(1)',
        'JavaScript:alert(document.cookie)',
        'data:text/html,<script>alert(1)</script>',
        'file:///etc/passwd',
        'content://com.android.contacts/contacts',
      ]) {
        expect(resolveInput(s, engine), isA<SearchFor>(), reason: s);
      }
    });

    test('credentials in URL are not navigated', () {
      expect(resolveInput('user:pass@evil.com', engine), isA<SearchFor>());
    });

    test('external schemes require confirmation', () {
      expect(resolveInput('mailto:a@b.com', engine), isA<ExternalTarget>());
      expect(resolveInput('tel:+49123', engine), isA<ExternalTarget>());
    });

    test('search engine is switchable', () {
      final g = resolveInput('cats', searchEngineById('google')) as SearchFor;
      expect(g.uri.host, 'www.google.com');
      expect(searchEngineById('nope').id, 'duckduckgo');
    });
  });

  group('classifyUrl', () {
    test('web and blank load', () {
      expect(classifyUrl(Uri.parse('https://a.com')), UrlDisposition.load);
      expect(classifyUrl(Uri.parse('about:blank')), UrlDisposition.load);
    });
    test('blocked', () {
      for (final s in [
        'javascript:void(0)',
        'file:///x',
        'data:,x',
        'about:config',
        'https://',
        'blob:https://a.com/1',
      ]) {
        expect(classifyUrl(Uri.parse(s)), UrlDisposition.blocked, reason: s);
      }
    });
    test('external', () {
      expect(classifyUrl(Uri.parse('intent://scan/#Intent;scheme=zxing;end')),
          UrlDisposition.external);
      expect(classifyUrl(Uri.parse('market://details?id=x')),
          UrlDisposition.external);
    });
  });

  group('host checks', () {
    test('private hosts', () {
      for (final h in [
        'localhost',
        '127.0.0.1',
        '10.0.0.5',
        '172.20.1.1',
        '192.168.0.1',
        '169.254.1.1',
        '[::1]',
        'intranet',
        'printer.local',
      ]) {
        expect(isPrivateOrLocalHost(h), isTrue, reason: h);
      }
      expect(isPrivateOrLocalHost('example.com'), isFalse);
      expect(isPrivateOrLocalHost('8.8.8.8'), isFalse);
    });

    test('safe remote urls', () {
      expect(isSafeRemoteHttpsUrl('https://example.com/privacy'), isTrue);
      expect(isSafeRemoteHttpsUrl('http://example.com'), isFalse);
      expect(isSafeRemoteHttpsUrl('https://127.0.0.1/x'), isFalse);
      expect(isSafeRemoteHttpsUrl('https://u:p@example.com'), isFalse);
      expect(isSafeRemoteHttpsUrl('javascript:alert(1)'), isFalse);
    });

    test('display host keeps punycode visible', () {
      expect(displayHost(Uri.parse('https://www.example.com/x')),
          'example.com');
      expect(displayHost(Uri.parse('https://xn--pple-43d.com')),
          'xn--pple-43d.com');
    });
  });
}
