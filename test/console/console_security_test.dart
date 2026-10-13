import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/features/console/domain/console_security.dart';

void main() {
  group('console URL', () {
    test('builds a QEMU noVNC URL scaled to the mobile viewport', () {
      final Uri uri = buildConsoleUri(
        origin: 'https://pve.example:8006/',
        consoleType: qemuConsoleType,
        node: 'pve-a',
        vmid: 101,
      );

      expect(uri.origin, 'https://pve.example:8006');
      expect(uri.path, '/');
      expect(uri.queryParameters, <String, String>{
        'console': 'kvm',
        'novnc': '1',
        'resize': 'scale',
        'node': 'pve-a',
        'vmid': '101',
      });
    });

    test('builds an LXC xterm.js URL', () {
      final Uri uri = buildConsoleUri(
        origin: 'https://10.10.10.10:8006',
        consoleType: lxcConsoleType,
        node: 'pve-b',
        vmid: 202,
      );

      expect(uri.queryParameters['console'], 'lxc');
      expect(uri.queryParameters['xtermjs'], '1');
      expect(uri.queryParameters, isNot(contains('novnc')));
      expect(uri.queryParameters, isNot(contains('resize')));
    });

    test('rejects non-HTTPS and path-scoped origins', () {
      expect(
        () => parseConsoleOrigin('http://pve.example:8006'),
        throwsFormatException,
      );
      expect(
        () => parseConsoleOrigin('https://pve.example:8006/api2/json'),
        throwsFormatException,
      );
      expect(
        () => parseConsoleOrigin('https://user@pve.example:8006'),
        throwsFormatException,
      );
    });

    test('allows only the exact HTTPS origin', () {
      final Uri allowed = parseConsoleOrigin('https://pve.example:8006');

      expect(
        hasSameHttpsOrigin(
          Uri.parse('https://pve.example:8006/?console=kvm'),
          allowed,
        ),
        isTrue,
      );
      expect(
        hasSameHttpsOrigin(Uri.parse('https://pve.example/'), allowed),
        isFalse,
      );
      expect(
        hasSameHttpsOrigin(Uri.parse('https://login.example:8006/'), allowed),
        isFalse,
      );
    });

    test('rejects invalid HTTPS ports before creating a cookie or WebView', () {
      for (final port in <int>[0, 65536]) {
        expect(
          () => parseConsoleOrigin('https://pve.example:$port'),
          throwsFormatException,
        );
      }
      expect(parseConsoleOrigin('https://pve.example:65535').port, 65535);
    });
  });

  group('certificate pin', () {
    const String abcSha256 =
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

    test('normalizes colon-separated uppercase fingerprints', () {
      expect(
        normalizeSha256Pin(
          'BA:78:16:BF:8F:01:CF:EA:41:41:40:DE:5D:AE:22:23:'
          'B0:03:61:A3:96:17:7A:9C:B4:10:FF:61:F2:00:15:AD',
        ),
        abcSha256,
      );
    });

    test('matches the SHA-256 digest of DER bytes exactly', () {
      final Uint8List bytes = Uint8List.fromList(utf8.encode('abc'));

      expect(derSha256Fingerprint(bytes), abcSha256);
      expect(certificateMatchesPin(bytes, abcSha256), isTrue);
      expect(
        certificateMatchesPin(
          bytes,
          'aa7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
        isFalse,
      );
    });

    test('fails closed for absent bytes or malformed pins', () {
      expect(certificateMatchesPin(null, abcSha256), isFalse);
      expect(certificateMatchesPin(Uint8List(0), abcSha256), isFalse);
      expect(() => normalizeSha256Pin('1234'), throwsFormatException);
    });
  });
}
