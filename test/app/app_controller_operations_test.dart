import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pve_manager/app/app_controller.dart';
import 'package:pve_manager/core/network/pve_api_client.dart';
import 'package:pve_manager/features/connections/data/connection_store.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';
import 'package:pve_manager/features/connections/domain/pve_session.dart';
import 'package:pve_manager/features/nodes/domain/pve_node.dart';
import 'package:pve_manager/presentation/view_models.dart';

void main() {
  late _ControllerHarness harness;

  setUp(() async {
    harness = _ControllerHarness();
    await harness.initialize();
  });

  tearDown(() => harness.controller.dispose());

  test('power action uses the current node after a guest migrates', () async {
    final resource = harness.controller.resourceViewModels.single;
    harness.nodeName = 'pve-b';

    await harness.controller.runResourceAction(
      resource,
      ResourcePowerAction.start,
    );

    expect(harness.powerRequests, hasLength(1));
    expect(
      harness.powerRequests.single.url.path,
      '/api2/json/nodes/pve-b/qemu/100/status/start',
    );
    expect(harness.controller.resourceViewModels.single.nodeName, 'pve-b');
  });

  test('revoked resource permission prevents the POST', () async {
    final resource = harness.controller.resourceViewModels.single;
    harness.allowPower = false;

    await harness.controller.runResourceAction(
      resource,
      ResourcePowerAction.start,
    );

    expect(harness.powerRequests, isEmpty);
    expect(
      harness.controller.resourceViewModels.single.capabilities.canPower,
      isFalse,
    );
    expect(harness.controller.notice, contains('操作已取消'));
  });

  test('a resource locked after selection prevents the POST', () async {
    final resource = harness.controller.resourceViewModels.single;
    harness.resourceLock = 'backup';

    await harness.controller.runResourceAction(
      resource,
      ResourcePowerAction.start,
    );

    expect(harness.powerRequests, isEmpty);
    expect(harness.controller.notice, contains('已锁定'));
  });

  test('revoked node permission prevents the POST', () async {
    final node = harness.controller.nodeViewModels.single;
    harness.allowPower = false;

    await harness.controller.runNodeAction(node, NodePowerAction.reboot);

    expect(harness.powerRequests, isEmpty);
    expect(harness.controller.notice, contains('命令已取消'));
  });

  test('console uses current location and checks current permission', () async {
    final resource = harness.controller.resourceViewModels.single;
    harness.nodeName = 'pve-b';
    harness.resourceStatus = 'running';

    final launch = await harness.controller.consoleLaunchFor(resource);

    expect(launch?.node, 'pve-b');
    harness.allowConsole = false;
    expect(await harness.controller.consoleLaunchFor(resource), isNull);
    expect(harness.controller.notice, contains('没有执行此操作的权限'));
    expect(harness.powerRequests, isEmpty);
  });

  test(
    'disconnection disables cached power and console capabilities',
    () async {
      final resource = harness.controller.resourceViewModels.single;
      harness.networkUnavailable = true;

      await harness.controller.refreshAll();

      final cached = harness.controller.resourceViewModels.single;
      expect(cached.capabilities.canPower, isFalse);
      expect(cached.capabilities.canConsole, isFalse);
      expect(
        harness.controller.nodeViewModels.single.capabilities.canPower,
        isFalse,
      );
      await harness.controller.runResourceAction(
        resource,
        ResourcePowerAction.start,
      );
      expect(await harness.controller.consoleLaunchFor(resource), isNull);
      expect(harness.powerRequests, isEmpty);
    },
  );

  test('HTML 401 expires the session and disables cached actions', () async {
    harness.unauthorized = true;

    await harness.controller.refreshAll();

    expect(
      harness.controller.connectionViewModels.single.status,
      ConnectionStatus.authenticationRequired,
    );
    expect(
      harness.controller.resourceViewModels.single.capabilities.canPower,
      isFalse,
    );
  });

  test(
    'removing a connection during preflight never sends a power command',
    () async {
      final resource = harness.controller.resourceViewModels.single;
      final blocked = Completer<void>();
      harness.resourceFetchGate = blocked;
      final operation = harness.controller.runResourceAction(
        resource,
        ResourcePowerAction.start,
      );
      await harness.resourceFetchStarted.future;
      await harness.controller.deleteConnection(harness.profile.id);
      blocked.complete();

      await operation;

      expect(harness.powerRequests, isEmpty);
      expect(harness.controller.profiles, isEmpty);
    },
  );

  test('a superseded login never completes the newer login flow', () async {
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    harness.loginGates['first-password'] = firstGate;
    harness.loginGates['second-password'] = secondGate;
    harness.loginStarted['first-password'] = Completer<void>();
    harness.loginStarted['second-password'] = Completer<void>();
    final first = harness.controller.beginConnection(
      _connectionValue(username: 'operator', password: 'first-password'),
      connectionId: harness.profile.id,
    );
    await harness.loginStarted['first-password']!.future;
    final second = harness.controller.beginConnection(
      _connectionValue(username: 'new-operator', password: 'second-password'),
      connectionId: harness.profile.id,
    );
    await harness.loginStarted['second-password']!.future;
    firstGate.complete();

    expect(await first, isA<ConnectionFlowFailed>());

    secondGate.complete();
    expect(await second, isA<ConnectionFlowSucceeded>());
    expect(harness.controller.profiles.single.username, 'new-operator');
    harness.resourceStatus = 'running';
    final launch = await harness.controller.consoleLaunchFor(
      harness.controller.resourceViewModels.single,
    );
    expect(launch?.ticket, contains('new-operator@pve'));
  });

  test(
    'an old guest task cannot complete or clear the new host action',
    () async {
      final oldGate = Completer<void>();
      final newGate = Completer<void>();
      harness.taskGates[harness.profile.host] = oldGate;
      harness.taskGates['replacement.example.test'] = newGate;
      harness.taskStarted[harness.profile.host] = Completer<void>();
      harness.taskStarted['replacement.example.test'] = Completer<void>();
      final oldOperation = harness.controller.runResourceAction(
        harness.controller.resourceViewModels.single,
        ResourcePowerAction.start,
      );
      await harness.taskStarted[harness.profile.host]!.future;
      harness.resourceStatus = 'stopped';
      expect(
        await harness.controller.beginConnection(
          _connectionValue(
            host: 'replacement.example.test',
            username: 'replacement-operator',
            password: 'replacement-password',
          ),
          connectionId: harness.profile.id,
        ),
        isA<ConnectionFlowSucceeded>(),
      );
      expect(
        harness.controller.resourceViewModels.single.operationMessage,
        isNull,
      );
      expect(harness.controller.resourceViewModels.single.activeAction, isNull);
      final newOperation = harness.controller.runResourceAction(
        harness.controller.resourceViewModels.single,
        ResourcePowerAction.start,
      );
      await harness.taskStarted['replacement.example.test']!.future;
      final newMessage =
          harness.controller.resourceViewModels.single.operationMessage;

      oldGate.complete();
      await oldOperation;

      expect(
        harness.controller.resourceViewModels.single.activeAction,
        ResourcePowerAction.start,
      );
      expect(
        harness.controller.resourceViewModels.single.operationMessage,
        newMessage,
      );
      newGate.complete();
      await newOperation;
      expect(harness.controller.resourceViewModels.single.activeAction, isNull);
      expect(
        harness.controller.resourceViewModels.single.operationMessage,
        '操作已完成。',
      );
    },
  );

  test(
    'an old node observer cannot complete or clear the new host action',
    () async {
      final oldGate = Completer<void>();
      final newGate = Completer<void>();
      harness.nodeTransitionGates[harness.profile.host] = oldGate;
      harness.nodeTransitionGates['replacement.example.test'] = newGate;
      harness.nodeTransitionStarted[harness.profile.host] = Completer<void>();
      harness.nodeTransitionStarted['replacement.example.test'] =
          Completer<void>();
      await harness.controller.runNodeAction(
        harness.controller.nodeViewModels.single,
        NodePowerAction.reboot,
      );
      await harness.nodeTransitionStarted[harness.profile.host]!.future;
      expect(
        await harness.controller.beginConnection(
          _connectionValue(
            host: 'replacement.example.test',
            username: 'replacement-operator',
            password: 'replacement-password',
          ),
          connectionId: harness.profile.id,
        ),
        isA<ConnectionFlowSucceeded>(),
      );
      expect(harness.controller.nodeViewModels.single.operationMessage, isNull);
      expect(harness.controller.nodeViewModels.single.activeAction, isNull);
      await harness.controller.runNodeAction(
        harness.controller.nodeViewModels.single,
        NodePowerAction.shutdown,
      );
      await harness.nodeTransitionStarted['replacement.example.test']!.future;
      final newMessage =
          harness.controller.nodeViewModels.single.operationMessage;

      oldGate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(
        harness.controller.nodeViewModels.single.activeAction,
        NodePowerAction.shutdown,
      );
      expect(
        harness.controller.nodeViewModels.single.operationMessage,
        newMessage,
      );
      newGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(harness.controller.nodeViewModels.single.activeAction, isNull);
      expect(
        harness.controller.nodeViewModels.single.operationMessage,
        '节点已离线。',
      );
    },
  );

  test(
    'a delayed pin read cannot send the newer password to the old host',
    () async {
      final pinGate = Completer<void>();
      harness.secrets.blockedReadKey =
          'pve.connection.connection-one.certificate_pin';
      harness.secrets.readGate = pinGate;
      final secondGate = Completer<void>();
      harness.loginGates['second-password'] = secondGate;
      harness.loginStarted['second-password'] = Completer<void>();
      harness.loginRequests.clear();
      final first = harness.controller.beginConnection(
        _connectionValue(
          host: 'first.example.test',
          username: 'operator',
          password: 'first-password',
        ),
        connectionId: harness.profile.id,
      );
      await harness.secrets.readStarted.future;
      final second = harness.controller.beginConnection(
        _connectionValue(
          host: 'second.example.test',
          username: 'new-operator',
          password: 'second-password',
        ),
        connectionId: harness.profile.id,
      );
      await harness.loginStarted['second-password']!.future;
      pinGate.complete();

      expect(await first, isA<ConnectionFlowFailed>());
      expect(harness.loginRequests, hasLength(1));
      expect(harness.loginRequests.single.url.host, 'second.example.test');
      expect(
        Uri.splitQueryString(harness.loginRequests.single.body)['password'],
        'second-password',
      );
      secondGate.complete();
      expect(await second, isA<ConnectionFlowSucceeded>());
      expect(harness.controller.profiles.single.host, 'second.example.test');
    },
  );

  test('a delayed saved-password read cannot replace a newer login', () async {
    final passwordGate = Completer<void>();
    harness.secrets.blockedReadKey = 'pve.connection.connection-one.password';
    harness.secrets.readGate = passwordGate;
    final secondGate = Completer<void>();
    harness.loginGates['second-password'] = secondGate;
    harness.loginStarted['second-password'] = Completer<void>();
    harness.loginRequests.clear();
    final first = harness.controller.beginConnection(
      _connectionValue(username: 'operator', password: ''),
      connectionId: harness.profile.id,
    );
    await harness.secrets.readStarted.future;
    final second = harness.controller.beginConnection(
      _connectionValue(username: 'new-operator', password: 'second-password'),
      connectionId: harness.profile.id,
    );
    await harness.loginStarted['second-password']!.future;
    passwordGate.complete();

    expect(await first, isA<ConnectionFlowFailed>());
    expect(harness.loginRequests, hasLength(1));
    secondGate.complete();
    expect(await second, isA<ConnectionFlowSucceeded>());
    expect(harness.controller.profiles.single.username, 'new-operator');
  });

  test(
    'replacement during profile save rolls back before the newer flow',
    () async {
      final writeGate = Completer<void>();
      harness.metadata.writeGate = writeGate;
      final secondGate = Completer<void>();
      harness.loginGates['second-password'] = secondGate;
      harness.loginStarted['second-password'] = Completer<void>();
      final first = harness.controller.beginConnection(
        _connectionValue(
          host: 'first.example.test',
          username: 'first-operator',
          password: 'first-password',
          rememberPassword: true,
        ),
        connectionId: harness.profile.id,
      );
      await harness.metadata.writeStarted.future;
      final second = harness.controller.beginConnection(
        _connectionValue(
          host: 'second.example.test',
          username: 'new-operator',
          password: 'second-password',
          rememberPassword: true,
        ),
        connectionId: harness.profile.id,
      );
      writeGate.complete();

      expect(await first, isA<ConnectionFlowFailed>());
      await harness.loginStarted['second-password']!.future;
      expect(harness.controller.profiles.single, harness.profile);
      expect(await harness.store.loadProfiles(), <ConnectionProfile>[
        harness.profile,
      ]);
      expect(
        await harness.store.readPassword(harness.profile.id),
        'offline-fixture-password',
      );
      secondGate.complete();
      expect(await second, isA<ConnectionFlowSucceeded>());
      expect(harness.controller.profiles.single.host, 'second.example.test');
      expect(
        (await harness.store.loadProfiles()).single.host,
        'second.example.test',
      );
      expect(
        await harness.store.readPassword(harness.profile.id),
        'second-password',
      );
    },
  );

  test(
    'cancel during password save restores the prior connection and secret',
    () async {
      final writeGate = Completer<void>();
      harness.secrets.writeGate = writeGate;
      final operation = harness.controller.beginConnection(
        _connectionValue(
          username: 'new-operator',
          password: 'first-password',
          rememberPassword: true,
        ),
        connectionId: harness.profile.id,
      );
      await harness.secrets.writeStarted.future;
      final cancellation = harness.controller.cancelPendingConnection();
      writeGate.complete();

      expect(await operation, isA<ConnectionFlowFailed>());
      await cancellation;
      expect(harness.controller.profiles.single, harness.profile);
      expect(await harness.store.loadProfiles(), <ConnectionProfile>[
        harness.profile,
      ]);
      expect(
        await harness.store.readPassword(harness.profile.id),
        'offline-fixture-password',
      );
    },
  );
}

ConnectionFormValue _connectionValue({
  required String username,
  required String password,
  String host = 'pve.example.test',
  bool rememberPassword = false,
}) => ConnectionFormValue(
  name: 'Lab',
  host: host,
  port: 8006,
  username: username,
  realm: 'pve',
  password: password,
  rememberPassword: rememberPassword,
);

class _ControllerHarness {
  final profile = ConnectionProfile(
    id: 'connection-one',
    name: 'Lab',
    host: 'pve.example.test',
    username: 'operator',
    rememberPassword: true,
  );
  late AppController controller;
  late ConnectionStore store;
  final metadata = _MemoryMetadataStore();
  final secrets = _MemorySecretStore();
  String nodeName = 'pve-a';
  String resourceStatus = 'stopped';
  String? resourceLock;
  bool allowPower = true;
  bool allowConsole = true;
  bool networkUnavailable = false;
  bool unauthorized = false;
  Completer<void>? resourceFetchGate;
  final resourceFetchStarted = Completer<void>();
  final powerRequests = <http.Request>[];
  final loginRequests = <http.Request>[];
  final loginGates = <String, Completer<void>>{};
  final loginStarted = <String, Completer<void>>{};
  final taskGates = <String, Completer<void>>{};
  final taskStarted = <String, Completer<void>>{};
  final nodeTransitionGates = <String, Completer<void>>{};
  final nodeTransitionStarted = <String, Completer<void>>{};

  Future<void> initialize() async {
    store = ConnectionStore(metadataStore: metadata, secretStore: secrets);
    await store.saveProfile(profile);
    await store.writePassword(profile, 'offline-fixture-password');
    controller = AppController(
      store: store,
      clientFactory: (profile, pin) => _FixtureApiClient(
        profile: profile,
        pinnedCertificateFingerprint: pin,
        client: MockClient(_respond),
        waitForTransition: () async {
          if (nodeTransitionGates[profile.host] case final gate?) {
            nodeTransitionStarted[profile.host]!.complete();
            await gate.future;
          }
        },
      ),
    );
    await controller.initialize();
  }

  Future<http.Response> _respond(http.Request request) async {
    if (networkUnavailable) throw const SocketException('offline fixture');
    if (unauthorized) return http.Response('<html>expired ticket</html>', 401);
    final path = request.url.path;
    if (path == '/api2/json/access/ticket') {
      loginRequests.add(request);
      final form = Uri.splitQueryString(request.body);
      final password = form['password'];
      if (loginGates[password] case final gate?) {
        loginStarted[password]!.complete();
        await gate.future;
      }
      final username = form['username'];
      final issuedAt = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
          .toRadixString(16);
      return _response(<String, Object?>{
        'username': username,
        'ticket': 'PVE:$username:$issuedAt::fixture',
        'CSRFPreventionToken': 'fixture-csrf',
      });
    }
    if (path == '/api2/json/access/permissions') {
      return _response(<String, Object?>{
        '/': <String, int>{
          'VM.Audit': 1,
          'Sys.Audit': 1,
          if (allowPower) 'VM.PowerMgmt': 1,
          if (allowPower) 'Sys.PowerMgmt': 1,
          if (allowConsole) 'VM.Console': 1,
        },
      });
    }
    if (path == '/api2/json/cluster/resources') {
      if (request.url.queryParameters['type'] == 'node') {
        return _response(<Object?>[
          <String, Object?>{
            'type': 'node',
            'node': nodeName,
            'status': 'online',
          },
        ]);
      }
      if (resourceFetchGate case final gate?) {
        if (!resourceFetchStarted.isCompleted) resourceFetchStarted.complete();
        await gate.future;
      }
      return _response(<Object?>[
        <String, Object?>{
          'type': 'qemu',
          'node': nodeName,
          'vmid': 100,
          'name': 'fixture-vm',
          'status': resourceStatus,
          if (resourceLock != null) 'lock': resourceLock,
        },
      ]);
    }
    if (request.method == 'POST') {
      powerRequests.add(request);
      resourceStatus = 'running';
      return _response('UPID:$nodeName:fixture:');
    }
    if (path.contains('/tasks/')) {
      if (taskGates[request.url.host] case final gate?) {
        taskStarted[request.url.host]!.complete();
        await gate.future;
      }
      return _response(<String, Object?>{
        'status': 'stopped',
        'exitstatus': 'OK',
      });
    }
    throw StateError('Unexpected fixture request: ${request.method} $path');
  }
}

class _FixtureApiClient extends PveApiClient {
  _FixtureApiClient({
    required super.profile,
    required super.pinnedCertificateFingerprint,
    required super.client,
    required this.waitForTransition,
  });

  final Future<void> Function() waitForTransition;

  @override
  Future<void> waitForNodePowerTransition(
    PveSession session,
    PveNode node,
    PveNodeAction action, {
    Duration timeout = const Duration(minutes: 5),
  }) => waitForTransition();
}

http.Response _response(Object? data) => http.Response(
  jsonEncode(<String, Object?>{'data': data}),
  200,
  headers: const <String, String>{'content-type': 'application/json'},
);

class _MemoryMetadataStore implements ProfileMetadataStore {
  final values = <String, String>{};
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (writeGate case final gate?) {
      writeGate = null;
      writeStarted.complete();
      await gate.future;
    }
    values[key] = value;
  }
}

class _MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  String? blockedReadKey;
  Completer<void>? readGate;
  final readStarted = Completer<void>();
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async {
    final value = values[key];
    if (key == blockedReadKey && readGate != null) {
      final gate = readGate!;
      blockedReadKey = null;
      readStarted.complete();
      await gate.future;
    }
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    if (writeGate case final gate?) {
      writeGate = null;
      writeStarted.complete();
      await gate.future;
    }
    values[key] = value;
  }
}
