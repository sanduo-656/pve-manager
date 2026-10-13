import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/core/errors/pve_exception.dart';
import 'package:pve_manager/core/network/pve_api_client.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';
import 'package:pve_manager/features/console/domain/console_security.dart';

void main() {
  test(
    'requires an explicit matching pin for an untrusted certificate',
    () async {
      final context = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(_certificate))
        ..usePrivateKeyBytes(utf8.encode(_privateKey));
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      final subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'username': 'operator@pve',
              'ticket': 'PVE:operator@pve:65A00000::ticket',
              'CSRFPreventionToken': 'csrf-token',
            },
          }),
        );
        await request.response.close();
      });
      final profile = ConnectionProfile(
        id: 'tls-test',
        name: 'TLS test',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        username: 'operator',
      );

      final unpinnedClient = PveApiClient(profile: profile);
      late PveUntrustedCertificateException untrusted;
      try {
        await unpinnedClient.login(password: 'secret');
        fail('The untrusted certificate should not be accepted.');
      } on PveUntrustedCertificateException catch (error) {
        untrusted = error;
      } finally {
        unpinnedClient.close();
      }

      expect(untrusted.host, profile.host);
      expect(untrusted.port, profile.port);
      expect(untrusted.actualFingerprint.split(':'), hasLength(32));

      await expectLater(
        verifyPinnedConsoleCertificate(
          origin: profile.origin,
          pinnedSha256: untrusted.actualFingerprint,
        ),
        completes,
      );
      await expectLater(
        verifyPinnedConsoleCertificate(
          origin: profile.origin,
          pinnedSha256: List<String>.filled(32, 'AA').join(':'),
        ),
        throwsA(isA<ConsoleCertificatePinException>()),
      );

      final pinnedClient = PveApiClient(
        profile: profile,
        pinnedCertificateFingerprint: untrusted.actualFingerprint,
      );
      final session = await pinnedClient.login(password: 'secret');
      pinnedClient.close();
      expect(session.connectionId, profile.id);

      final mismatchedClient = PveApiClient(
        profile: profile,
        pinnedCertificateFingerprint: List<String>.filled(32, 'AA').join(':'),
      );
      await expectLater(
        mismatchedClient.login(password: 'secret'),
        throwsA(
          isA<PveCertificateMismatchException>()
              .having(
                (error) => error.actualFingerprint,
                'actualFingerprint',
                untrusted.actualFingerprint,
              )
              .having(
                (error) => error.expectedFingerprint,
                'expectedFingerprint',
                List<String>.filled(32, 'AA').join(':'),
              ),
        ),
      );
      mismatchedClient.close();

      await subscription.cancel();
      await server.close(force: true);
    },
  );
}

const String _certificate = '''
-----BEGIN CERTIFICATE-----
MIICjTCCAfYCCQDR1evIEbvoVjANBgkqhkiG9w0BAQUFADCBijELMAkGA1UEBhMC
VVMxEjAQBgNVBAgMCVNvbWV3aGVyZTERMA8GA1UEBwwIU29tZUNpdHkxDTALBgNV
BAoMBENvcnAxETAPBgNVBAsMCFNvZnR3YXJlMRIwEAYDVQQDDAlsb2NhbGhvc3Qx
HjAcBgkqhkiG9w0BCQEWD2FkbWluQGxvY2FsaG9zdDAeFw0xMjA2MDgxOTE0Mzha
Fw0xMjA3MDgxOTE0MzhaMIGKMQswCQYDVQQGEwJVUzESMBAGA1UECAwJU29tZXdo
ZXJlMREwDwYDVQQHDAhTb21lQ2l0eTENMAsGA1UECgwEQ29ycDERMA8GA1UECwwI
U29mdHdhcmUxEjAQBgNVBAMMCWxvY2FsaG9zdDEeMBwGCSqGSIb3DQEJARYPYWRt
aW5AbG9jYWxob3N0MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC/Vj4UCdQI
N0IMCHDWwDo3QyH9I8sBm/OwIiiJbQ0RpyfWCn4ilzZwu98okwUCu5PwlFQZd67a
DooxhFS2FSw4iRZCUGJlgV7BG1JX9q0xqVy33V6rxFFYQYHw6r7FHPaw2FuRCOoi
uDqE+ua6lbV2YP/eXiRnq5hT5vWfEX5rYwIDAQABMA0GCSqGSIb3DQEBBQUAA4GB
ADQFczkmr+91I3id7HH1voh9YKVqA9nh1yYFCkonsDPXBEJIZEyYa9HaWVkcMMgo
F7bJbWKyaYXW818XPXuOmSBI7dmaMtqITEJWsxdcMVKYCOMtjTLwquPki6xXZxNb
y/zubrV+P4XN0Wi0hoDU/0/RNQOuAF1w7UOQsUmn1ihj
-----END CERTIFICATE-----
''';

const String _privateKey = '''
-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQC/Vj4UCdQIN0IMCHDWwDo3QyH9I8sBm/OwIiiJbQ0RpyfWCn4i
lzZwu98okwUCu5PwlFQZd67aDooxhFS2FSw4iRZCUGJlgV7BG1JX9q0xqVy33V6r
xFFYQYHw6r7FHPaw2FuRCOoiuDqE+ua6lbV2YP/eXiRnq5hT5vWfEX5rYwIDAQAB
AoGAaL5oq4WZ2omNkZLJWvbOp9QLdk2y44WhSOnaMSlOvzw3tZf25y7KcbqXdtnN
I2rWmRxKUcrQILVW97aOvUMn+jOCN6+IY1kiT6Un4H1Ow+rVj3CDvCjBCZhfkExK
osTzpwbiRyHueWOLOB3RZUNXC+5OfTBVoYgQp85INykwUHECQQD10XsOKDtkuCh4
yNf68lXC7TUSPAwAjX+I4xJ1UWMO5DWBpuyuA2GSlYHWZg4ae0xm9zUijb6A5WDW
aVTvi9S5AkEAx0MSU2qD837lXAjkcyBS9WqtoJebC263uUaiQ8WZQhDE+R8aeXj+
e80hY8FOc6WogC2VbQgYO52t82KWLDKq+wJAS+2Xl+jfZ53mimBnLhE6YkpIsUgw
4N7T/OE+q1QnR8s/p7t6sclDkzZw81t0kcNx9v/2vqSPqlqvjardXFyRqQJBAIAW
jWExx0BvAeD3lmKrFKjNum7RBcmDknZ3ATevfaUKQpQhelM7g9rxMdV+HYAZrQc4
RiWgXnN0GK2rYf1nVKECQQCo5UHoukW89+UX/SbamoMeUZJxL3bQAqv71B59C6cy
NQuDZlHOqDajyxaX2y8tJWgk3ciGXlIqByHQFXb2Rhuw
-----END RSA PRIVATE KEY-----
''';
