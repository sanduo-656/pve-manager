import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pve_manager/core/errors/pve_exception.dart';
import 'package:pve_manager/core/network/pve_api_client.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';
import 'package:pve_manager/features/connections/domain/pve_session.dart';
import 'package:pve_manager/features/nodes/domain/pve_node_metrics.dart';

void main() {
  group('node metrics parsing', () {
    test('reads node status fields with their native units', () {
      final metrics = PveNodeMetricsSnapshot.fromJson(<String, Object?>{
        'cpu': '0.25',
        'wait': 0.03,
        'cpuinfo': <String, Object?>{'cpus': '16', 'model': 'Example CPU'},
        'loadavg': <Object?>['1.20', '2.30', '3.40'],
        'memory': <String, Object?>{
          'used': '4294967296',
          'total': 17179869184,
          'available': 10737418240,
          'free': 2147483648,
        },
        'swap': <String, Object?>{'used': 0, 'total': '8589934592'},
        'rootfs': <String, Object?>{
          'used': 10737418240,
          'total': '107374182400',
          'avail': 91268055040,
          'free': 96636764160,
        },
        'uptime': '12345.9',
        'pveversion': 'pve-manager/9.0.0/example',
      });

      expect(metrics.cpuUsage, 0.25);
      expect(metrics.ioWait, 0.03);
      expect(metrics.cpuCount, 16);
      expect(metrics.cpuModel, 'Example CPU');
      expect(metrics.loadAverage, <double>[1.2, 2.3, 3.4]);
      expect(metrics.memoryUsedBytes, 4294967296);
      expect(metrics.memoryTotalBytes, 17179869184);
      expect(metrics.memoryAvailableBytes, 10737418240);
      expect(metrics.swapUsedBytes, 0);
      expect(metrics.swapTotalBytes, 8589934592);
      expect(metrics.rootfsUsedBytes, 10737418240);
      expect(metrics.rootfsTotalBytes, 107374182400);
      expect(metrics.rootfsAvailableBytes, 91268055040);
      expect(metrics.uptimeSeconds, 12345);
      expect(metrics.pveVersion, 'pve-manager/9.0.0/example');
    });

    test('missing and non-finite metrics stay unknown', () {
      final metrics = PveNodeMetricsSnapshot.fromJson(<String, Object?>{
        'cpu': double.nan,
        'wait': 'Infinity',
        'memory': <String, Object?>{'used': 'NaN', 'free': 2048},
        'rootfs': <String, Object?>{'free': 4096},
        'cpuinfo': <String, Object?>{'cpus': double.infinity},
        'uptime': 'unknown',
      });

      expect(metrics.cpuUsage, isNull);
      expect(metrics.ioWait, isNull);
      expect(metrics.cpuCount, isNull);
      expect(metrics.memoryUsedBytes, isNull);
      expect(metrics.memoryTotalBytes, isNull);
      expect(metrics.memoryAvailableBytes, isNull);
      expect(metrics.swapUsedBytes, isNull);
      expect(metrics.rootfsAvailableBytes, isNull);
      expect(metrics.uptimeSeconds, isNull);
      expect(metrics.loadAverage, isEmpty);
    });

    test('does not shift load average positions around an invalid entry', () {
      final metrics = PveNodeMetricsSnapshot.fromJson(<String, Object?>{
        'loadavg': <Object?>['1', null, '3'],
      });

      expect(metrics.loadAverage, isEmpty);
    });
  });

  group('RRD parsing', () {
    test(
      'uses Unix seconds, native ratios, and already-derived network rate',
      () {
        final point = PveNodeRrdPoint.fromJson(<String, Object?>{
          'time': '1720000000.5',
          'cpu': '0.42',
          'iowait': 0.08,
          'loadavg': '2.6',
          'memused': '4294967296.5',
          'memtotal': 17179869184,
          'memavailable': 10737418240,
          'swapused': '128',
          'swaptotal': 8589934592,
          'rootused': '10737418240',
          'roottotal': 107374182400,
          'netin': '1048576.5',
          'netout': 2097152,
        });

        expect(
          point.time,
          DateTime.fromMillisecondsSinceEpoch(1720000000500, isUtc: true),
        );
        expect(point.cpuUsage, 0.42);
        expect(point.ioWait, 0.08);
        expect(point.loadAverage, 2.6);
        expect(point.memoryUsedBytes, 4294967296.5);
        expect(point.memoryTotalBytes, 17179869184);
        expect(point.memoryAvailableBytes, 10737418240);
        expect(point.swapUsedBytes, 128);
        expect(point.swapTotalBytes, 8589934592);
        expect(point.rootfsUsedBytes, 10737418240);
        expect(point.rootfsTotalBytes, 107374182400);
        expect(point.netInBytesPerSecond, 1048576.5);
        expect(point.netOutBytesPerSecond, 2097152);
      },
    );

    test('retains a timestamp-only sample as a gap', () {
      final point = PveNodeRrdPoint.fromJson(<String, Object?>{'time': 0});

      expect(point.time, DateTime.utc(1970));
      expect(point.cpuUsage, isNull);
      expect(point.memoryUsedBytes, isNull);
      expect(point.memoryAvailableBytes, isNull);
      expect(point.netInBytesPerSecond, isNull);
      expect(point.netOutBytesPerSecond, isNull);
    });

    test('preserves zero while rejecting null and non-finite readings', () {
      final point = PveNodeRrdPoint.fromJson(<String, Object?>{
        'time': 1720000000,
        'cpu': 0,
        'iowait': null,
        'memused': double.nan,
        'memtotal': double.infinity,
        'netin': 'NaN',
        'netout': '-Infinity',
      });

      expect(point.cpuUsage, 0);
      expect(point.ioWait, isNull);
      expect(point.memoryUsedBytes, isNull);
      expect(point.memoryTotalBytes, isNull);
      expect(point.netInBytesPerSecond, isNull);
      expect(point.netOutBytesPerSecond, isNull);
    });

    test('rejects samples with missing or invalid time', () {
      for (final value in <Object?>[
        null,
        'NaN',
        double.infinity,
        'bad',
        9e12,
      ]) {
        expect(
          () => PveNodeRrdPoint.fromJson(<String, Object?>{'time': value}),
          throwsFormatException,
        );
      }
    });
  });

  group('storage parsing', () {
    test('reads storage capacity and numeric or string flags', () {
      final storage = PveStorageStatus.fromJson(<String, Object?>{
        'storage': 'local-zfs',
        'type': 'zfspool',
        'active': 1,
        'enabled': '1',
        'shared': false,
        'used': '4096',
        'total': 16384,
        'avail': '8192',
      });

      expect(storage.id, 'local-zfs');
      expect(storage.type, 'zfspool');
      expect(storage.isActive, isTrue);
      expect(storage.isEnabled, isTrue);
      expect(storage.isShared, isFalse);
      expect(storage.usedBytes, 4096);
      expect(storage.totalBytes, 16384);
      expect(storage.availableBytes, 8192);
    });

    test('missing flags and space stay unknown for disabled storages', () {
      final storage = PveStorageStatus.fromJson(<String, Object?>{
        'storage': 'archive',
        'type': 'nfs',
        'enabled': 0,
        'active': 'unknown',
        'used': 'NaN',
      });

      expect(storage.isEnabled, isFalse);
      expect(storage.isActive, isNull);
      expect(storage.isShared, isNull);
      expect(storage.usedBytes, isNull);
      expect(storage.totalBytes, isNull);
      expect(storage.availableBytes, isNull);
    });
  });

  group('node monitoring API', () {
    test(
      'uses authenticated GET requests and safely encoded node segments',
      () async {
        final requests = <http.Request>[];
        const node = 'node/with space?#';
        final client = PveApiClient(
          profile: _profile,
          client: MockClient((request) async {
            requests.add(request);
            switch (request.url.pathSegments.last) {
              case 'status':
                return _response(<String, Object?>{'cpu': 0.12});
              case 'rrddata':
                return _response(<Object?>[]);
              case 'storage':
                return _response(<Object?>[]);
              default:
                throw StateError('Unexpected endpoint: ${request.url}');
            }
          }),
        );

        final metrics = await client.fetchNodeMetrics(_session, node: node);
        await client.fetchNodeHistory(
          _session,
          node: node,
          timeframe: PveNodeTimeframe.day,
        );
        await client.fetchNodeStorages(_session, node: node);

        expect(metrics.cpuUsage, 0.12);
        expect(requests, hasLength(3));
        for (final request in requests) {
          expect(request.method, 'GET');
          expect(request.url.scheme, 'https');
          expect(request.url.host, _profile.host);
          expect(request.url.port, 8006);
          expect(request.url.pathSegments.take(4), <String>[
            'api2',
            'json',
            'nodes',
            node,
          ]);
          expect(request.url.fragment, isEmpty);
          expect(request.headers['cookie'], 'PVEAuthCookie=${_session.ticket}');
          expect(request.headers['CSRFPreventionToken'], isNull);
        }
        expect(requests[0].url.pathSegments.last, 'status');
        expect(requests[0].url.queryParameters, isEmpty);
        expect(requests[1].url.queryParameters, <String, String>{
          'timeframe': 'day',
          'cf': 'AVERAGE',
        });
        expect(requests[2].url.pathSegments.last, 'storage');
        expect(requests[2].url.queryParameters, isEmpty);
      },
    );

    test(
      'sorts RRD samples and keeps unknown samples without filling gaps',
      () async {
        final client = PveApiClient(
          profile: _profile,
          client: MockClient(
            (_) async => _response(<Object?>[
              <String, Object?>{'time': 1720000300, 'cpu': 0.5},
              <String, Object?>{'time': 1720000060},
              <String, Object?>{'time': 1720000000, 'cpu': 0},
            ]),
          ),
        );

        final points = await client.fetchNodeHistory(
          _session,
          node: 'pve',
          timeframe: PveNodeTimeframe.hour,
        );

        expect(points, hasLength(3));
        expect(points.map((point) => point.cpuUsage), <double?>[0, null, 0.5]);
        expect(
          points[1].time.difference(points[0].time),
          const Duration(seconds: 60),
        );
        expect(
          points[2].time.difference(points[1].time),
          const Duration(seconds: 240),
        );
      },
    );

    test('reads storage list without hiding disabled entries', () async {
      final client = PveApiClient(
        profile: _profile,
        client: MockClient(
          (_) async => _response(<Object?>[
            <String, Object?>{
              'storage': 'local',
              'type': 'dir',
              'active': 1,
              'enabled': 1,
              'total': 4096,
              'used': 1024,
              'avail': 2048,
            },
            <String, Object?>{'storage': 'backup', 'type': 'nfs', 'enabled': 0},
          ]),
        ),
      );

      final storages = await client.fetchNodeStorages(_session, node: 'pve');

      expect(storages.map((storage) => storage.id), <String>[
        'local',
        'backup',
      ]);
      expect(storages[0].availableBytes, 2048);
      expect(storages[1].isEnabled, isFalse);
      expect(storages[1].totalBytes, isNull);
    });

    test(
      'all monitoring methods reject sessions from another connection',
      () async {
        var requests = 0;
        final client = PveApiClient(
          profile: _profile,
          client: MockClient((_) async {
            requests++;
            return _response(<String, Object?>{});
          }),
        );
        final wrongSession = _session.copyWith(connectionId: 'other');

        for (final operation in _operations(client, wrongSession)) {
          await expectLater(operation(), throwsA(isA<PveProtocolException>()));
        }
        expect(requests, 0);
      },
    );

    test(
      'permission and authentication failures propagate for each endpoint',
      () async {
        for (final status in <int>[401, 403]) {
          final client = PveApiClient(
            profile: _profile,
            client: MockClient(
              (_) async => http.Response(
                jsonEncode(<String, Object?>{'message': 'Access denied'}),
                status,
              ),
            ),
          );
          for (final operation in _operations(client, _session)) {
            await expectLater(
              operation(),
              throwsA(
                status == 401
                    ? isA<PveAuthenticationException>()
                    : isA<PvePermissionException>(),
              ),
            );
          }
        }
      },
    );

    test('invalid RRD timestamps surface a protocol error', () async {
      final client = PveApiClient(
        profile: _profile,
        client: MockClient(
          (_) async => _response(<Object?>[
            <String, Object?>{'cpu': 0.5},
          ]),
        ),
      );

      await expectLater(
        client.fetchNodeHistory(
          _session,
          node: 'pve',
          timeframe: PveNodeTimeframe.hour,
        ),
        throwsA(isA<PveProtocolException>()),
      );
    });

    test('invalid response shapes surface protocol errors', () async {
      final client = PveApiClient(
        profile: _profile,
        client: MockClient((_) async => _response(null)),
      );

      for (final operation in _operations(client, _session)) {
        await expectLater(operation(), throwsA(isA<PveProtocolException>()));
      }
    });
  });
}

List<Future<Object?> Function()> _operations(
  PveApiClient client,
  PveSession session,
) {
  return <Future<Object?> Function()>[
    () => client.fetchNodeMetrics(session, node: 'pve'),
    () => client.fetchNodeHistory(
      session,
      node: 'pve',
      timeframe: PveNodeTimeframe.hour,
    ),
    () => client.fetchNodeStorages(session, node: 'pve'),
  ];
}

http.Response _response(Object? data) {
  return http.Response(
    jsonEncode(<String, Object?>{'data': data}),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

final _profile = ConnectionProfile(
  id: 'monitoring-connection',
  name: 'Lab',
  host: 'pve.example.test',
  username: 'operator',
);

final _session = PveSession(
  connectionId: _profile.id,
  username: 'operator@pve',
  ticket: 'monitoring-ticket',
  csrfPreventionToken: 'monitoring-csrf',
  issuedAt: DateTime.utc(2026, 10, 13),
  expiresAt: DateTime.utc(2026, 10, 13, 2),
);
