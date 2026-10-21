import 'package:flutter_test/flutter_test.dart';
import 'package:vela_browser/core/file_names.dart';
import 'package:vela_browser/core/version.dart';

void main() {
  group('sanitizeFileName', () {
    test('strips traversal and separators', () {
      expect(sanitizeFileName('../../etc/passwd'), 'passwd');
      expect(sanitizeFileName(r'..\..\windows\system32\x.txt'), 'x.txt');
      expect(sanitizeFileName('..'), 'download');
      expect(sanitizeFileName(''), 'download');
      expect(sanitizeFileName(null, fallback: 'file'), 'file');
    });

    test('removes control, reserved and bidi characters', () {
      expect(sanitizeFileName('a\u0000b<c>.txt'), 'a_b_c_.txt');
      expect(sanitizeFileName('invoice\u202Etxt.exe'),
          'invoice_txt.exe.download');
    });

    test('hidden files lose leading dots', () {
      expect(sanitizeFileName('.bashrc'), 'bashrc');
    });

    test('dangerous extensions are neutralised', () {
      expect(sanitizeFileName('app.apk'), 'app.apk.download');
      expect(sanitizeFileName('page.HTML'), 'page.HTML.download');
      expect(sanitizeFileName('song.mp3'), 'song.mp3');
    });

    test('reserved windows names', () {
      expect(sanitizeFileName('CON.txt'), '_CON.txt');
    });

    test('length is bounded and extension kept', () {
      final n = sanitizeFileName('${'a' * 500}.pdf');
      expect(n.length, lessThanOrEqualTo(120));
      expect(n.endsWith('.pdf'), isTrue);
    });
  });

  test('content-disposition parsing', () {
    expect(fileNameFromContentDisposition('attachment; filename="r.pdf"'),
        'r.pdf');
    expect(
        fileNameFromContentDisposition(
            "attachment; filename*=UTF-8''%D8%AA%D9%82%D8%B1%D9%8A%D8%B1.pdf"),
        'تقرير.pdf');
    expect(fileNameFromContentDisposition(null), isNull);
  });

  test('uniqueFileName', () {
    expect(uniqueFileName('a.txt', {}), 'a.txt');
    expect(uniqueFileName('a.txt', {'a.txt', 'a (1).txt'}), 'a (2).txt');
  });

  test('version comparison', () {
    expect(compareVersions('1.2.3', '1.2.3'), 0);
    expect(compareVersions('1.10.0', '1.9.9'), 1);
    expect(compareVersions('1.0', '1.0.1'), -1);
    expect(compareVersions('2.0.0+5', '2.0.0'), 0);
    expect(versionInRange('1.5.0', '1.0.0', null), isTrue);
    expect(versionInRange('0.9.0', '1.0.0', null), isFalse);
    expect(versionInRange('2.0.0', null, '1.9.9'), isFalse);
  });
}
