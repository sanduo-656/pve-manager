import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/app/app_controller.dart';
import 'package:pve_manager/features/connections/data/connection_store.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';
import 'package:pve_manager/presentation/view_models.dart';

void main() {
  test(
    'changing connection identity never reads or sends an old password',
    () async {
      final metadata = _MemoryMetadataStore();
      final secrets = _RecordingSecretStore();
      final store = ConnectionStore(
        metadataStore: metadata,
        secretStore: secrets,
      );
      final profile = ConnectionProfile(
        id: 'connection-one',
        name: 'Old PVE',
        host: 'old-pve.example.test',
        username: 'operator',
        rememberPassword: false,
      );
      await store.saveProfile(profile);
      secrets.values['pve.connection.connection-one.password'] = 'old-secret';

      final controller = AppController(store: store);
      await controller.initialize();
      secrets.readKeys.clear();

      final result = await controller.beginConnection(
        const ConnectionFormValue(
          name: 'New PVE',
          host: 'new-pve.example.test',
          port: 8006,
          username: 'new-operator',
          realm: 'pve',
          password: '',
          rememberPassword: false,
        ),
        connectionId: profile.id,
        saveOnSuccess: false,
      );

      expect(result, isA<ConnectionFlowFailed>());
      expect(
        secrets.readKeys,
        isNot(contains('pve.connection.connection-one.password')),
      );
      controller.dispose();
    },
  );

  for (final delayPin in <bool>[false, true]) {
    test(
      'disposing during ${delayPin ? 'pin' : 'profile'} loading never creates a client',
      () async {
        final profile = ConnectionProfile(
          id: 'connection-one',
          name: 'Lab',
          host: 'pve.example.test',
          username: 'operator',
        );
        final store = _DelayedStartupStore(profile, delayPin: delayPin);
        var createdClients = 0;
        final controller = AppController(
          store: store,
          clientFactory: (_, _) {
            createdClients += 1;
            throw StateError('No client should be created after disposal.');
          },
        );
        final initializing = controller.initialize();
        await store.started.future;
        controller.dispose();
        store.release.complete();

        await initializing;

        expect(createdClients, 0);
      },
    );
  }
}

class _DelayedStartupStore extends ConnectionStore {
  _DelayedStartupStore(this.profile, {required this.delayPin})
    : super(
        metadataStore: _MemoryMetadataStore(),
        secretStore: _RecordingSecretStore(),
      );

  final ConnectionProfile profile;
  final bool delayPin;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<ConnectionProfile>> loadProfiles() async {
    if (!delayPin) {
      started.complete();
      await release.future;
    }
    return <ConnectionProfile>[profile];
  }

  @override
  Future<String?> readCertificatePin(ConnectionProfile profile) async {
    if (delayPin) {
      started.complete();
      await release.future;
    }
    return null;
  }
}

class _MemoryMetadataStore implements ProfileMetadataStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _RecordingSecretStore implements SecretStore {
  final Map<String, String> values = <String, String>{};
  final List<String> readKeys = <String>[];

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async {
    readKeys.add(key);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
