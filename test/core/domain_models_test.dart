import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/core/network/certificate_fingerprint.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';
import 'package:pve_manager/features/connections/domain/pve_session.dart';
import 'package:pve_manager/features/nodes/domain/pve_node.dart';
import 'package:pve_manager/features/resources/domain/pve_permissions.dart';
import 'package:pve_manager/features/resources/domain/pve_resource.dart';

void main() {
  group('ConnectionProfile', () {
    test('normalizes a URL host and never serializes secrets', () {
      final profile = ConnectionProfile(
        id: 'one',
        name: 'Lab',
        host: 'https://pve.example.test:8006/',
        username: 'operator',
        realm: 'pam',
        rememberPassword: true,
      );

      expect(profile.host, 'pve.example.test');
      expect(profile.userId, 'operator@pam');
      expect(profile.authority, 'pve.example.test:8006');
      expect(profile.apiBaseUri.path, '/api2/json/');
      expect(profile.toJson(), isNot(contains('password')));
      expect(profile.toJson(), isNot(contains('certificatePin')));
      expect(ConnectionProfile.fromJson(profile.toJson()), profile);
    });

    test('keeps a realm already present in the username', () {
      final profile = ConnectionProfile(
        id: 'one',
        name: 'Lab',
        host: '::1',
        username: 'operator@pve',
        realm: '',
      );

      expect(profile.userId, 'operator@pve');
      expect(profile.origin.toString(), 'https://[::1]:8006');
    });
  });

  test('PveSession renews after 90 minutes and expires after its deadline', () {
    final issuedAt = DateTime.utc(2026, 1, 1);
    final session = PveSession(
      connectionId: 'one',
      username: 'operator@pve',
      ticket: 'ticket',
      csrfPreventionToken: 'csrf',
      issuedAt: issuedAt,
      expiresAt: issuedAt.add(const Duration(hours: 2)),
    );

    expect(
      session.shouldRenew(issuedAt.add(const Duration(minutes: 89))),
      false,
    );
    expect(
      session.shouldRenew(issuedAt.add(const Duration(minutes: 90))),
      true,
    );
    expect(session.isExpired(issuedAt.add(const Duration(hours: 2))), true);
  });

  test('maps QEMU and node metrics without losing numeric types', () {
    final resource = PveResource.fromClusterJson(
      connectionId: 'one',
      json: <String, Object?>{
        'type': 'qemu',
        'vmid': 101.0,
        'node': 'pve-a',
        'name': 'router',
        'status': 'running',
        'cpu': 0.25,
        'maxcpu': 4,
        'mem': 1024,
        'maxmem': 4096,
        'uptime': 60,
      },
    );
    final node = PveNode.fromClusterJson(
      connectionId: 'one',
      json: <String, Object?>{
        'type': 'node',
        'node': 'pve-a',
        'status': 'online',
        'cpu': 0.5,
        'maxcpu': 16,
        'mem': 2048,
        'maxmem': 8192,
        'disk': 1024,
        'maxdisk': 16384,
        'uptime': 120,
      },
    );

    expect(resource.type, PveResourceType.qemu);
    expect(resource.vmId, 101);
    expect(resource.status, PveResourceStatus.running);
    expect(resource.permissionPath, '/vms/101');
    expect(node.isOnline, true);
    expect(node.permissionPath, '/nodes/pve-a');
  });

  test('permission lookup inherits privileges from parent paths', () {
    final permissions = PvePermissions.fromApiJson(
      connectionId: 'one',
      json: <String, Object?>{
        '/': <String, Object?>{'Sys.Audit': 1},
        '/vms': <String, Object?>{'VM.Audit': 1},
        '/vms/101': <String, Object?>{'VM.PowerMgmt': 1, 'VM.Console': 0},
      },
    );

    expect(permissions.canAuditResource(101), true);
    expect(permissions.canPowerResource(101), true);
    expect(permissions.canOpenConsole(101), true);
    expect(permissions.propagates('VM.Console', '/vms/101'), false);
    expect(permissions.allows('VM.Console', '/vms/101/child'), false);
    expect(permissions.canAuditNode('pve-a'), true);
  });

  group('CertificateFingerprint', () {
    test('creates and normalizes a SHA-256 fingerprint', () {
      final fingerprint = CertificateFingerprint.fromDer(<int>[97, 98, 99]);

      expect(
        fingerprint,
        'BA:78:16:BF:8F:01:CF:EA:41:41:40:DE:5D:AE:22:23:'
        'B0:03:61:A3:96:17:7A:9C:B4:10:FF:61:F2:00:15:AD',
      );
      expect(
        CertificateFingerprint.matches(
          fingerprint,
          fingerprint.toLowerCase().replaceAll(':', '-'),
        ),
        true,
      );
    });

    test('rejects non-SHA-256 values', () {
      expect(
        () => CertificateFingerprint.normalize('AA:BB'),
        throwsFormatException,
      );
      expect(
        () => CertificateFingerprint.normalize(
          '${List<String>.filled(32, 'AA').join(':')}ZZ',
        ),
        throwsFormatException,
      );
    });
  });
}
