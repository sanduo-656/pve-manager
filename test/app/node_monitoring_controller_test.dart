import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pve_manager/app/app_controller.dart';
import 'package:pve_manager/core/errors/pve_exception.dart';
import 'package:pve_manager/core/network/pve_api_client.dart';
import 'package:pve_manager/features/connections/data/connection_store.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';
import 'package:pve_manager/features/nodes/domain/pve_node_metrics.dart';
import 'package:pve_manager/presentation/view_models.dart';

void main() {
  group('node monitoring', () {
    late _MonitoringHarness harness;

    setUp(() async {
      harness = _MonitoringHarness();
      await harness.initialize();
      harness.controller.setSection(AppSection.nodes);
    });

    tearDown(() => harness.controller.dispose());

    test(
      'selection loads snapshot, history and storages independently',
      () async {
        expect(harness.controller.selectedNodeMonitoring, isNull);
        final snapshotGate = harness.block('/nodes/pve-a/status');

        harness.select('pve-a');
        await snapshotGate.started.future;
        await _settle();

        final loading = harness.controller.selectedNodeMonitoring!;
        expect(loading.isLoadingSnapshot, isTrue);
        expect(loading.isLoadingHistory, isFalse);
        expect(loading.isLoadingStorage, isFalse);
        expect(loading.points.single.cpuUsage, 0.4);
        expect(loading.storages.single.id, 'local-pve-a');
        expect(loading.historyUpdatedAt, isNotNull);
        expect(loading.storageUpdatedAt, isNotNull);
        expect(loading.snapshotUpdatedAt, isNull);

        snapshotGate.release.complete();
        await _settle();

        final loaded = harness.controller.selectedNodeMonitoring!;
        expect(loaded.snapshot!.cpuUsage, 0.2);
        expect(loaded.snapshotUpdatedAt, isNotNull);
        expect(loaded.isLoadingSnapshot, isFalse);
        expect(loaded.isStale, isFalse);
        expect(
          harness.controller.connectionViewModels.single.status,
          ConnectionStatus.connected,
        );
      },
    );

    test(
      'failed history and forbidden storage preserve their last good data',
      () async {
        harness.select('pve-a');
        await _settle();
        final previous = harness.controller.selectedNodeMonitoring!;
        harness.cpuUsage = 0.65;
        harness.historyStatus = 500;
        harness.storageStatus = 403;

        await harness.controller.refreshNodeMonitoring(forceHistory: true);

        final current = harness.controller.selectedNodeMonitoring!;
        expect(current.snapshot!.cpuUsage, 0.65);
        expect(current.snapshotError, isNull);
        expect(
          current.snapshotUpdatedAt,
          isNot(equals(previous.snapshotUpdatedAt)),
        );
        expect(current.points, previous.points);
        expect(current.storages, previous.storages);
        expect(current.historyUpdatedAt, previous.historyUpdatedAt);
        expect(current.storageUpdatedAt, previous.storageUpdatedAt);
        expect(current.historyError, isNotNull);
        expect(current.storageError, isNotNull);
        expect(current.isStale, isTrue);
        expect(current.isLoadingSnapshot, isFalse);
        expect(current.isLoadingHistory, isFalse);
        expect(current.isLoadingStorage, isFalse);
        expect(
          harness.controller.connectionViewModels.single.status,
          ConnectionStatus.connected,
        );
        expect(harness.controller.partialErrors, isEmpty);
      },
    );

    test('snapshot failure keeps the snapshot and its update time', () async {
      harness.select('pve-a');
      await _settle();
      final previous = harness.controller.selectedNodeMonitoring!;
      harness.snapshotStatus = 503;
      harness.historyCpuUsage = 0.75;

      await harness.controller.refreshNodeMonitoring(forceHistory: true);

      final current = harness.controller.selectedNodeMonitoring!;
      expect(current.snapshot, same(previous.snapshot));
      expect(current.snapshotUpdatedAt, previous.snapshotUpdatedAt);
      expect(current.snapshotError, isNotNull);
      expect(current.isStale, isTrue);
      expect(current.points.single.cpuUsage, 0.75);
      expect(current.historyError, isNull);
      expect(
        harness.controller.connectionViewModels.single.status,
        ConnectionStatus.connected,
      );
    });

    test('ordinary refresh reuses recent history and storage data', () async {
      harness.select('pve-a');
      await _settle();
      final previous = harness.controller.selectedNodeMonitoring!;
      final historyRequests = harness.requestsFor('/rrddata').length;
      final storageRequests = harness.requestsFor('/storage').length;
      final snapshotRequests = harness.requestsFor('/status').length;
      harness.cpuUsage = 0.55;

      await harness.controller.refreshNodeMonitoring();

      final current = harness.controller.selectedNodeMonitoring!;
      expect(current.snapshot!.cpuUsage, 0.55);
      expect(harness.requestsFor('/status'), hasLength(snapshotRequests + 1));
      expect(harness.requestsFor('/rrddata'), hasLength(historyRequests));
      expect(harness.requestsFor('/storage'), hasLength(storageRequests));
      expect(current.historyUpdatedAt, previous.historyUpdatedAt);
      expect(current.storageUpdatedAt, previous.storageUpdatedAt);
    });

    test(
      'sample age marks cached data stale until a successful refresh',
      () async {
        harness.select('pve-a');
        await _settle();
        final sampledAt =
            harness.controller.selectedNodeMonitoring!.snapshotUpdatedAt!;
        expect(harness.controller.selectedNodeMonitoring!.isStale, isFalse);
        harness.clock = sampledAt.add(const Duration(seconds: 46));

        expect(harness.controller.selectedNodeMonitoring!.isStale, isTrue);

        await harness.controller.refreshNodeMonitoring();

        expect(harness.controller.selectedNodeMonitoring!.isStale, isFalse);
        expect(
          harness.controller.selectedNodeMonitoring!.snapshotUpdatedAt,
          harness.clock,
        );
      },
    );

    test(
      'a delayed previous node request cannot overwrite the selected node',
      () async {
        final previousGate = harness.block('/nodes/pve-a/status');
        harness.select('pve-a');
        await previousGate.started.future;
        harness.select('pve-b');
        await _settle();

        expect(harness.controller.selectedNode!.name, 'pve-b');
        expect(
          harness.controller.selectedNodeMonitoring!.snapshot!.cpuUsage,
          0.8,
        );

        previousGate.release.complete();
        await _settle();

        expect(harness.controller.selectedNode!.name, 'pve-b');
        expect(
          harness.controller.selectedNodeMonitoring!.snapshot!.cpuUsage,
          0.8,
        );
      },
    );

    test('a delayed timeframe cannot overwrite the latest history', () async {
      harness.select('pve-a');
      await _settle();
      final dayGate = harness.block('/nodes/pve-a/rrddata', timeframe: 'day');
      harness.controller.setNodeMonitoringTimeframe(PveNodeTimeframe.day);
      await dayGate.started.future;
      harness.controller.setNodeMonitoringTimeframe(PveNodeTimeframe.week);
      await _settle();

      final latest = harness.controller.selectedNodeMonitoring!;
      expect(latest.timeframe, PveNodeTimeframe.week);
      expect(latest.points.single.cpuUsage, 0.7);

      dayGate.release.complete();
      await _settle();

      final current = harness.controller.selectedNodeMonitoring!;
      expect(current.timeframe, PveNodeTimeframe.week);
      expect(current.points.single.cpuUsage, 0.7);
      expect(current.historyUpdatedAt, latest.historyUpdatedAt);
      expect(current.isLoadingHistory, isFalse);
    });

    test(
      'returning to a node retries its cancelled first history and storage',
      () async {
        final historyGate = harness.block(
          '/nodes/pve-a/rrddata',
          timeframe: 'hour',
        );
        final storageGate = harness.block('/nodes/pve-a/storage');
        harness.select('pve-a');
        await Future.wait(<Future<void>>[
          historyGate.started.future,
          storageGate.started.future,
        ]);
        await _settle();
        expect(harness.controller.selectedNodeMonitoring!.points, isEmpty);
        expect(harness.controller.selectedNodeMonitoring!.storages, isEmpty);

        try {
          harness.select('pve-b');
          await _settle();
          harness.historyCpuUsage = 0.9;
          harness.select('pve-a');
          await _settle();

          final current = harness.controller.selectedNodeMonitoring!;
          expect(current.points.single.cpuUsage, 0.9);
          expect(current.storages.single.id, 'local-pve-a');
          expect(current.isLoadingHistory, isFalse);
          expect(current.isLoadingStorage, isFalse);
          expect(
            harness
                .requestsFor('/rrddata')
                .where((request) => request.url.path.contains('/pve-a/')),
            hasLength(2),
          );
          expect(
            harness
                .requestsFor('/storage')
                .where((request) => request.url.path.contains('/pve-a/')),
            hasLength(2),
          );
        } finally {
          historyGate.release.complete();
          storageGate.release.complete();
          await _settle();
        }

        expect(
          harness.controller.selectedNodeMonitoring!.points.single.cpuUsage,
          0.9,
        );
      },
    );

    for (final renewalFailure in <(String, Object, ConnectionStatus)>[
      (
        'network',
        const SocketException('Fixture renewal network failure'),
        ConnectionStatus.networkUnavailable,
      ),
      (
        'certificate',
        const PveCertificateMismatchException(
          host: 'pve.example.test',
          port: 8006,
          expectedFingerprint: 'AA:BB',
          actualFingerprint: 'CC:DD',
        ),
        ConnectionStatus.certificateRequired,
      ),
    ]) {
      test(
        'monitoring retains ${renewalFailure.$1} status when renewal fails',
        () async {
          harness.controller.dispose();
          harness = _MonitoringHarness(ticketAge: const Duration(minutes: 91));
          await harness.initialize();
          harness.controller.setSection(AppSection.nodes);
          harness.select('pve-a');
          await _settle();
          final previous = harness.controller.selectedNodeMonitoring!;
          final renewalCount = harness.renewalRequests.length;
          harness.renewalError = renewalFailure.$2;

          await harness.controller.refreshNodeMonitoring(forceHistory: true);

          expect(harness.renewalRequests, hasLength(renewalCount + 1));
          expect(
            harness.controller.connectionViewModels.single.status,
            renewalFailure.$3,
          );
          final current = harness.controller.selectedNodeMonitoring!;
          expect(current.snapshot, same(previous.snapshot));
          expect(current.snapshotUpdatedAt, previous.snapshotUpdatedAt);
          expect(current.isStale, isTrue);
          expect(current.snapshotError, isNotNull);
          expect(current.snapshotError, isNot(contains('会话已过期')));
          expect(current.isLoadingSnapshot, isFalse);
          expect(current.isLoadingHistory, isFalse);
          expect(current.isLoadingStorage, isFalse);
          harness.renewalError = null;
          await harness.controller.refreshAll();
          if (renewalFailure.$1 == 'network') {
            expect(
              harness.controller.connectionViewModels.single.status,
              ConnectionStatus.connected,
            );
            expect(
              harness.controller.selectedNodeMonitoring!.snapshotError,
              isNull,
            );
            expect(
              harness.renewalRequests.length,
              greaterThan(renewalCount + 1),
            );
          } else {
            expect(
              harness.controller.connectionViewModels.single.status,
              ConnectionStatus.certificateRequired,
            );
            expect(
              harness.controller.connectionViewModels.single.certificateStatus,
              CertificateStatus.changed,
            );
            expect(harness.renewalRequests, hasLength(renewalCount + 1));
          }
        },
      );
    }

    test(
      'replacing a connection identity rejects results from the old client',
      () async {
        harness.select('pve-a');
        await _settle();
        final previousGate = harness.block('/nodes/pve-a/status');
        final previousHistoryGate = harness.block(
          '/nodes/pve-a/rrddata',
          timeframe: harness.controller.selectedNodeMonitoring!.timeframe.name,
        );
        final previousStorageGate = harness.block('/nodes/pve-a/storage');
        harness.cpuUsage = 0.95;
        final previousRefresh = harness.controller.refreshNodeMonitoring(
          forceHistory: true,
        );
        await Future.wait(<Future<void>>[
          previousGate.started.future,
          previousHistoryGate.started.future,
          previousStorageGate.started.future,
        ]);

        final result = await harness.controller.beginConnection(
          const ConnectionFormValue(
            name: 'Replacement',
            host: 'replacement.example.test',
            port: 8006,
            username: 'replacement-operator',
            realm: 'pve',
            password: 'replacement-password',
            rememberPassword: true,
          ),
          connectionId: harness.profile.id,
        );
        expect(result, isA<ConnectionFlowSucceeded>());
        harness.select('pve-a');
        await _settle();
        await harness.controller.refreshNodeMonitoring(forceHistory: true);
        expect(
          harness.controller.selectedNodeMonitoring!.snapshot!.cpuUsage,
          0.6,
        );
        expect(
          harness.controller.selectedNodeMonitoring!.points.single.cpuUsage,
          0.6,
        );
        expect(
          harness.controller.selectedNodeMonitoring!.storages.single.id,
          'replacement-local-pve-a',
        );

        previousGate.release.complete();
        previousHistoryGate.release.complete();
        previousStorageGate.release.complete();
        await previousRefresh;

        expect(
          harness.controller.profiles.single.host,
          'replacement.example.test',
        );
        expect(
          harness.controller.selectedNodeMonitoring!.snapshot!.cpuUsage,
          0.6,
        );
        expect(
          harness.controller.selectedNodeMonitoring!.points.single.cpuUsage,
          0.6,
        );
        expect(
          harness.controller.selectedNodeMonitoring!.storages.single.id,
          'replacement-local-pve-a',
        );
        expect(
          harness.controller.selectedNodeMonitoring!.snapshotError,
          isNull,
        );
      },
    );

    test(
      'deleting a connection rejects its pending monitoring request',
      () async {
        final gate = harness.block('/nodes/pve-a/status');
        harness.select('pve-a');
        await gate.started.future;

        await harness.controller.deleteConnection(harness.profile.id);
        gate.release.complete();
        await _settle();

        expect(harness.controller.profiles, isEmpty);
        expect(harness.controller.selectedNode, isNull);
        expect(harness.controller.selectedNodeMonitoring, isNull);
        expect(harness.controller.nodeViewModels, isEmpty);
      },
    );
  });

  testWidgets(
    'monitoring polls only while viewing a selected node in foreground',
    (tester) async {
      final harness = _MonitoringHarness();
      await harness.initialize();
      try {
        await tester.pump(const Duration(seconds: 16));
        expect(harness.monitoringRequests, isEmpty);
        harness.controller.setSection(AppSection.nodes);
        harness.select('pve-a');
        await tester.pump();
        final firstCount = harness.requestsFor('/status').length;
        expect(firstCount, greaterThan(0));

        await tester.pump(const Duration(seconds: 16));
        expect(harness.requestsFor('/status').length, greaterThan(firstCount));

        harness.controller.setSection(AppSection.resources);
        await tester.pump();
        final hiddenCount = harness.monitoringRequests.length;
        await tester.pump(const Duration(seconds: 31));
        expect(harness.monitoringRequests, hasLength(hiddenCount));

        harness.controller.setSection(AppSection.nodes);
        await tester.pump();
        harness.controller.setForeground(false);
        final backgroundCount = harness.monitoringRequests.length;
        await tester.pump(const Duration(seconds: 31));
        expect(harness.monitoringRequests, hasLength(backgroundCount));

        harness.controller.setForeground(true);
        await tester.pump();
        harness.controller.selectNode(null);
        await tester.pump();
        final unselectedCount = harness.monitoringRequests.length;
        await tester.pump(const Duration(seconds: 31));
        expect(harness.monitoringRequests, hasLength(unselectedCount));
        expect(harness.controller.selectedNodeMonitoring, isNull);
      } finally {
        harness.controller.dispose();
      }
    },
  );
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

class _MonitoringHarness {
  _MonitoringHarness({this.ticketAge = Duration.zero});

  final profile = ConnectionProfile(
    id: 'connection-one',
    name: 'Lab',
    host: 'pve.example.test',
    username: 'operator',
    rememberPassword: true,
  );
  late AppController controller;
  final monitoringRequests = <http.Request>[];
  final renewalRequests = <http.Request>[];
  final _gates = <String, List<_RequestGate>>{};
  double cpuUsage = 0.2;
  double historyCpuUsage = 0.4;
  int snapshotStatus = 200;
  int historyStatus = 200;
  int storageStatus = 200;
  DateTime? clock;
  final Duration ticketAge;
  Object? renewalError;

  Future<void> initialize() async {
    final store = ConnectionStore(
      metadataStore: _MemoryMetadataStore(),
      secretStore: _MemorySecretStore(),
    );
    await store.saveProfile(profile);
    await store.writePassword(profile, 'fixture-password');
    controller = AppController(
      store: store,
      now: () => clock ?? DateTime.now(),
      clientFactory: (profile, pin) => PveApiClient(
        profile: profile,
        pinnedCertificateFingerprint: pin,
        client: MockClient(_respond),
      ),
    );
    await controller.initialize();
  }

  void select(String name) => controller.selectNode(
    controller.nodeViewModels.singleWhere((node) => node.name == name),
  );

  List<http.Request> requestsFor(String suffix) => monitoringRequests
      .where((request) => request.url.path.endsWith(suffix))
      .toList();

  _RequestGate block(String path, {String? timeframe}) {
    final key = _requestKey('/api2/json$path', timeframe);
    final gate = _RequestGate();
    (_gates[key] ??= <_RequestGate>[]).add(gate);
    return gate;
  }

  Future<http.Response> _respond(http.Request request) async {
    final path = request.url.path;
    if (path == '/api2/json/access/ticket') {
      final form = Uri.splitQueryString(request.body);
      final username = form['username'];
      if (form['password']?.startsWith('PVE:') == true) {
        renewalRequests.add(request);
        if (renewalError case final error?) throw error;
      }
      final issuedAt =
          (DateTime.now().subtract(ticketAge).millisecondsSinceEpoch ~/ 1000)
              .toRadixString(16);
      return _response(<String, Object?>{
        'username': username,
        'ticket': 'PVE:$username:$issuedAt::fixture',
        'CSRFPreventionToken': 'fixture-csrf',
      });
    }
    if (path == '/api2/json/access/permissions') {
      return _response(<String, Object?>{
        '/': <String, int>{'Sys.Audit': 1, 'Datastore.Audit': 1, 'VM.Audit': 1},
      });
    }
    if (path == '/api2/json/cluster/resources') {
      return _response(
        request.url.queryParameters['type'] == 'node'
            ? <Object?>[
                for (final name in <String>['pve-a', 'pve-b'])
                  <String, Object?>{
                    'type': 'node',
                    'node': name,
                    'status': 'online',
                  },
              ]
            : <Object?>[],
      );
    }
    if (path == '/api2/json/version') {
      return _response(<String, Object?>{'version': '9.0'});
    }
    if (path.startsWith('/api2/json/nodes/')) {
      monitoringRequests.add(request);
      final response = _monitoringResponse(request);
      final key = _requestKey(path, request.url.queryParameters['timeframe']);
      final gates = _gates[key];
      if (gates != null && gates.isNotEmpty) {
        final gate = gates.removeAt(0);
        gate.started.complete();
        await gate.release.future;
      }
      return response;
    }
    throw StateError('Unexpected fixture request: ${request.method} $path');
  }

  http.Response _monitoringResponse(http.Request request) {
    final path = request.url.path;
    final node = request.url.pathSegments[3];
    final replacement = request.url.host == 'replacement.example.test';
    if (path.endsWith('/status')) {
      if (snapshotStatus != 200) return _errorResponse(snapshotStatus);
      return _response(<String, Object?>{
        'cpu': replacement
            ? 0.6
            : node == 'pve-b'
            ? 0.8
            : cpuUsage,
        'wait': 0.03,
        'cpuinfo': <String, Object?>{'cpus': 8, 'model': 'Fixture CPU'},
        'memory': <String, Object?>{
          'used': 4294967296,
          'total': 8589934592,
          'available': 4294967296,
        },
        'swap': <String, Object?>{'used': 0, 'total': 2147483648},
        'rootfs': <String, Object?>{
          'used': 10737418240,
          'total': 107374182400,
          'avail': 96636764160,
        },
        'uptime': 3600,
        'loadavg': <String>['0.20', '0.10', '0.05'],
      });
    }
    if (path.endsWith('/rrddata')) {
      if (historyStatus != 200) return _errorResponse(historyStatus);
      final timeframe = request.url.queryParameters['timeframe'];
      return _response(<Object?>[
        <String, Object?>{
          'time': 1700000000,
          'cpu': replacement
              ? 0.6
              : timeframe == 'day'
              ? 0.5
              : timeframe == 'week'
              ? 0.7
              : historyCpuUsage,
          'iowait': 0.02,
          'memused': 4294967296,
          'memtotal': 8589934592,
          'rootused': 10737418240,
          'roottotal': 107374182400,
          'netin': 1024,
          'netout': 2048,
        },
      ]);
    }
    if (path.endsWith('/storage')) {
      if (storageStatus != 200) return _errorResponse(storageStatus);
      return _response(<Object?>[
        <String, Object?>{
          'storage': '${replacement ? 'replacement-' : ''}local-$node',
          'type': 'dir',
          'active': 1,
          'enabled': 1,
          'shared': 0,
          'used': 10737418240,
          'total': 107374182400,
          'avail': 96636764160,
        },
      ]);
    }
    throw StateError('Unexpected monitoring request: $path');
  }

  static String _requestKey(String path, String? timeframe) =>
      '$path${timeframe == null ? '' : '?$timeframe'}';
}

class _RequestGate {
  final started = Completer<void>();
  final release = Completer<void>();
}

http.Response _response(Object? data) => http.Response(
  jsonEncode(<String, Object?>{'data': data}),
  200,
  headers: const <String, String>{'content-type': 'application/json'},
);

http.Response _errorResponse(int status) => http.Response(
  jsonEncode(<String, Object?>{'message': 'Fixture monitoring failure'}),
  status,
  headers: const <String, String>{'content-type': 'application/json'},
);

class _MemoryMetadataStore implements ProfileMetadataStore {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

class _MemorySecretStore implements SecretStore {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
