import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pve_manager/core/errors/pve_exception.dart';
import 'package:pve_manager/core/network/pve_api_client.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';
import 'package:pve_manager/features/connections/domain/pve_session.dart';
import 'package:pve_manager/features/nodes/domain/pve_node.dart';
import 'package:pve_manager/features/resources/domain/pve_resource.dart';
import 'package:pve_manager/features/resources/domain/pve_task.dart';

void main() {
  group('authentication', () {
    test(
      'logs in with form encoding and builds an in-memory session',
      () async {
        late http.Request captured;
        final client = PveApiClient(
          profile: _profile,
          client: MockClient((request) async {
            captured = request;
            return _response(<String, Object?>{
              'username': 'operator@pve',
              'ticket': 'PVE:operator@pve:65A00000::signature',
              'CSRFPreventionToken': 'csrf-token',
            });
          }),
        );

        final session = await client.login(password: 'a password & symbols');
        final form = Uri.splitQueryString(captured.body);

        expect(captured.method, 'POST');
        expect(captured.url.path, '/api2/json/access/ticket');
        expect(captured.headers['content-type'], contains('form-urlencoded'));
        expect(form['username'], 'operator@pve');
        expect(form['password'], 'a password & symbols');
        expect(form['new-format'], '1');
        expect(session.ticket, contains('signature'));
        expect(session.csrfPreventionToken, 'csrf-token');
        expect(
          session.expiresAt.difference(session.issuedAt),
          const Duration(hours: 2),
        );
      },
    );

    test(
      'surfaces a full signed TOTP challenge and available methods',
      () async {
        final challengeJson = Uri.encodeComponent(
          jsonEncode(<String, Object?>{
            'totp': true,
            'webauthn': <String, Object?>{'challenge': 'value'},
          }),
        );
        final challenge = 'PVE:!tfa!$challengeJson:65A00000::signature';
        final client = PveApiClient(
          profile: _profile,
          client: MockClient(
            (_) async => _response(<String, Object?>{
              'username': 'operator@pve',
              'ticket': challenge,
            }),
          ),
        );

        await expectLater(
          client.login(password: 'secret'),
          throwsA(
            isA<PveTotpRequiredException>()
                .having((error) => error.challenge, 'challenge', challenge)
                .having(
                  (error) => error.availableMethods,
                  'availableMethods',
                  containsAll(<String>['totp', 'webauthn']),
                ),
          ),
        );
      },
    );

    test('rejects unsupported-only second factor methods explicitly', () async {
      final challengeJson = Uri.encodeComponent(
        jsonEncode(<String, Object?>{
          'webauthn': <String, Object?>{'challenge': 'value'},
        }),
      );
      final client = PveApiClient(
        profile: _profile,
        client: MockClient(
          (_) async => _response(<String, Object?>{
            'username': 'operator@pve',
            'ticket': 'PVE:!tfa!$challengeJson:65A00000::signature',
          }),
        ),
      );

      await expectLater(
        client.login(password: 'secret'),
        throwsA(
          isA<PveUnsupportedSecondFactorException>().having(
            (error) => error.availableMethods,
            'availableMethods',
            contains('webauthn'),
          ),
        ),
      );
    });

    test(
      'submits the complete challenge and preserves TOTP leading zeros',
      () async {
        late Map<String, String> form;
        final client = PveApiClient(
          profile: _profile,
          client: MockClient((request) async {
            form = Uri.splitQueryString(request.body);
            return _response(<String, Object?>{
              'username': 'operator@pve',
              'ticket': 'PVE:operator@pve:65A00000::complete',
              'CSRFPreventionToken': 'csrf-complete',
            });
          }),
        );

        await client.completeTotp(
          challenge: 'full-signed-challenge',
          code: '001234',
        );

        expect(form['password'], 'totp:001234');
        expect(form['tfa-challenge'], 'full-signed-challenge');
        expect(form['new-format'], '1');
      },
    );

    test('accepts the official 2 to 16 digit TOTP range', () async {
      final client = PveApiClient(
        profile: _profile,
        client: MockClient(
          (_) async => _response(<String, Object?>{
            'username': 'operator@pve',
            'ticket': 'PVE:operator@pve:65A00000::complete',
            'CSRFPreventionToken': 'csrf-complete',
          }),
        ),
      );

      await expectLater(
        client.completeTotp(challenge: 'challenge', code: '01'),
        completes,
      );
      await expectLater(
        client.completeTotp(challenge: 'challenge', code: '1'),
        throwsA(isA<PveAuthenticationException>()),
      );
      await expectLater(
        client.completeTotp(challenge: 'challenge', code: '1234ab'),
        throwsA(isA<PveAuthenticationException>()),
      );
    });

    test('renews a ticket by using the existing ticket as password', () async {
      late Map<String, String> form;
      final client = PveApiClient(
        profile: _profile,
        client: MockClient((request) async {
          form = Uri.splitQueryString(request.body);
          return _response(<String, Object?>{
            'username': 'operator@pve',
            'ticket': 'PVE:operator@pve:65A00001::renewed',
            'CSRFPreventionToken': 'csrf-renewed',
          });
        }),
      );

      final renewed = await client.renewSession(_session);

      expect(form['password'], _session.ticket);
      expect(form['username'], _session.username);
      expect(renewed.ticket, contains('renewed'));
    });
  });

  test('unwraps resources, nodes, and inherited permissions', () async {
    final client = PveApiClient(
      profile: _profile,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/cluster/resources') &&
            request.url.queryParameters['type'] == 'vm') {
          return _response(<Object?>[
            <String, Object?>{
              'type': 'qemu',
              'vmid': 100,
              'node': 'pve-a',
              'name': 'vm',
              'status': 'running',
            },
            <String, Object?>{
              'type': 'lxc',
              'vmid': 101,
              'node': 'pve-a',
              'name': 'ct',
              'status': 'stopped',
            },
          ]);
        }
        if (request.url.path.endsWith('/cluster/resources')) {
          return _response(<Object?>[
            <String, Object?>{
              'type': 'node',
              'node': 'pve-a',
              'status': 'online',
            },
          ]);
        }
        return _response(<String, Object?>{
          '/vms': <String, Object?>{'VM.Audit': 1},
        });
      }),
    );

    final resources = await client.fetchResources(_session);
    final nodes = await client.fetchNodes(_session);
    final permissions = await client.fetchPermissions(_session);

    expect(resources.map((item) => item.type), <PveResourceType>[
      PveResourceType.qemu,
      PveResourceType.lxc,
    ]);
    expect(nodes.single.name, 'pve-a');
    expect(permissions.canAuditResource(100), true);
  });

  test(
    'sends ticket and CSRF headers and polls an encoded UPID to OK',
    () async {
      const upid = 'UPID:pve-a:00000001:00000002:vmstart:100:operator@pve:';
      var pollCount = 0;
      final client = PveApiClient(
        profile: _profile,
        delay: (_) async {},
        client: MockClient((request) async {
          if (request.method == 'POST') {
            expect(
              request.headers['cookie'],
              'PVEAuthCookie=${_session.ticket}',
            );
            expect(
              request.headers['csrfpreventiontoken'],
              _session.csrfPreventionToken,
            );
            expect(
              request.url.pathSegments,
              containsAllInOrder(<String>['qemu', '100', 'status', 'start']),
            );
            return _response(upid);
          }
          expect(request.url.pathSegments, contains(upid));
          pollCount += 1;
          return _response(<String, Object?>{
            'status': pollCount == 1 ? 'running' : 'stopped',
            if (pollCount > 1) 'exitstatus': 'OK',
          });
        }),
      );

      final task = await client.powerResource(
        _session,
        _resource,
        PveResourceAction.start,
      );
      final completed = await client.waitForTask(_session, task);

      expect(completed.succeeded, true);
      expect(pollCount, 2);
    },
  );

  test('treats a stopped non-OK task as a failed operation', () async {
    final client = PveApiClient(
      profile: _profile,
      client: MockClient(
        (_) async => _response(<String, Object?>{
          'status': 'stopped',
          'exitstatus': 'permission denied',
        }),
      ),
    );

    await expectLater(
      client.waitForTask(
        _session,
        const PveTask(
          connectionId: 'connection-one',
          node: 'pve-a',
          upid: 'UPID:pve-a:task:',
          status: PveTaskStatus.running,
        ),
      ),
      throwsA(
        isA<PveApiException>()
            .having((error) => error.code, 'code', 'permission denied')
            .having(
              (error) => error.operationMayHaveSucceeded,
              'operationMayHaveSucceeded',
              true,
            ),
      ),
    );
  });

  test('node reboot uses a non-retried form POST', () async {
    var requestCount = 0;
    final client = PveApiClient(
      profile: _profile,
      client: MockClient((request) async {
        requestCount += 1;
        expect(request.url.path, '/api2/json/nodes/pve-a/status');
        expect(Uri.splitQueryString(request.body)['command'], 'reboot');
        return _response(null);
      }),
    );

    await client.powerNode(_session, _node, PveNodeAction.reboot);

    expect(requestCount, 1);
  });

  test('does not treat transient transport loss as node shutdown', () async {
    var now = DateTime.utc(2026, 1, 1);
    final client = PveApiClient(
      profile: _profile,
      now: () => now,
      delay: (duration) async => now = now.add(duration),
      taskPollInterval: const Duration(seconds: 1),
      client: MockClient((_) async => throw const SocketException('offline')),
    );

    await expectLater(
      client.waitForNodePowerTransition(
        _session,
        _node,
        PveNodeAction.shutdown,
        timeout: const Duration(seconds: 2),
      ),
      throwsA(
        isA<PveTimeoutException>().having(
          (error) => error.operationMayHaveSucceeded,
          'operationMayHaveSucceeded',
          true,
        ),
      ),
    );
  });

  test('confirms reboot only after explicit offline then online', () async {
    var now = DateTime.utc(2026, 1, 1);
    var requestCount = 0;
    final client = PveApiClient(
      profile: _profile,
      now: () => now,
      delay: (duration) async => now = now.add(duration),
      taskPollInterval: const Duration(seconds: 1),
      client: MockClient((_) async {
        requestCount += 1;
        return _response(<Object?>[
          <String, Object?>{
            'type': 'node',
            'node': 'pve-a',
            'status': requestCount == 1 ? 'offline' : 'online',
            'uptime': requestCount == 1 ? 0 : 5,
          },
        ]);
      }),
    );

    await client.waitForNodePowerTransition(
      _session,
      _node,
      PveNodeAction.reboot,
      timeout: const Duration(seconds: 3),
    );

    expect(requestCount, 2);
  });

  test(
    'marks a mutating timeout as possibly submitted and does not retry',
    () async {
      var requestCount = 0;
      final client = PveApiClient(
        profile: _profile,
        requestTimeout: const Duration(milliseconds: 1),
        client: MockClient((_) async {
          requestCount += 1;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _response('UPID:pve-a:task:');
        }),
      );

      await expectLater(
        client.powerResource(_session, _resource, PveResourceAction.shutdown),
        throwsA(
          isA<PveTimeoutException>().having(
            (error) => error.operationMayHaveSucceeded,
            'operationMayHaveSucceeded',
            true,
          ),
        ),
      );
      expect(requestCount, 1);
    },
  );

  test('maps authentication and permission HTTP failures separately', () async {
    final unauthorized = PveApiClient(
      profile: _profile,
      client: MockClient(
        (_) async => _response(null, statusCode: 401, message: 'bad ticket'),
      ),
    );
    final forbidden = PveApiClient(
      profile: _profile,
      client: MockClient(
        (_) async => _response(null, statusCode: 403, message: 'denied'),
      ),
    );

    await expectLater(
      unauthorized.fetchResources(_session),
      throwsA(isA<PveAuthenticationException>()),
    );
    await expectLater(
      forbidden.fetchResources(_session),
      throwsA(isA<PvePermissionException>()),
    );
  });

  test('classifies non-JSON HTTP failures by status', () async {
    for (final statusCode in <int>[401, 403, 502]) {
      final client = PveApiClient(
        profile: _profile,
        client: MockClient(
          (_) async => http.Response('<html>proxy error</html>', statusCode),
        ),
      );
      await expectLater(
        client.fetchResources(_session),
        throwsA(switch (statusCode) {
          401 => isA<PveAuthenticationException>(),
          403 => isA<PvePermissionException>(),
          _ => isA<PveApiException>(),
        }),
      );
    }
  });

  test('still rejects malformed JSON from a successful response', () async {
    final client = PveApiClient(
      profile: _profile,
      client: MockClient((_) async => http.Response('not JSON', 200)),
    );
    await expectLater(
      client.fetchResources(_session),
      throwsA(isA<PveProtocolException>()),
    );
  });
}

final ConnectionProfile _profile = ConnectionProfile(
  id: 'connection-one',
  name: 'Lab',
  host: 'pve.example.test',
  username: 'operator',
);

final PveSession _session = PveSession(
  connectionId: 'connection-one',
  username: 'operator@pve',
  ticket: 'PVE:operator@pve:65A00000::ticket',
  csrfPreventionToken: 'csrf-token',
  issuedAt: DateTime.utc(2026, 1, 1),
  expiresAt: DateTime.utc(2026, 1, 1, 2),
);

const PveResource _resource = PveResource(
  connectionId: 'connection-one',
  node: 'pve-a',
  vmId: 100,
  name: 'test-vm',
  type: PveResourceType.qemu,
  status: PveResourceStatus.stopped,
  cpuUsage: 0,
  maxCpu: 2,
  memoryBytes: 0,
  maxMemoryBytes: 1024,
  uptimeSeconds: 0,
);

const PveNode _node = PveNode(
  connectionId: 'connection-one',
  name: 'pve-a',
  status: PveNodeStatus.online,
  cpuUsage: 0,
  maxCpu: 8,
  memoryBytes: 0,
  maxMemoryBytes: 1024,
  diskBytes: 0,
  maxDiskBytes: 1024,
  uptimeSeconds: 0,
);

http.Response _response(Object? data, {int statusCode = 200, String? message}) {
  final body = <String, Object?>{'data': data};
  if (message != null) {
    body['message'] = message;
  }
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
