import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/core/errors/pve_exception.dart';
import 'package:pve_manager/features/connections/data/connection_store.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';

void main() {
  late _MemoryMetadataStore metadata;
  late _MemorySecretStore secrets;
  late ConnectionStore store;

  setUp(() {
    metadata = _MemoryMetadataStore();
    secrets = _MemorySecretStore();
    store = ConnectionStore(metadataStore: metadata, secretStore: secrets);
  });

  test('stores profile metadata without a password', () async {
    final profile = _profile(rememberPassword: true);

    await store.saveProfile(profile);
    await store.writePassword(profile, 'correct horse battery staple');

    expect(await store.loadProfiles(), <ConnectionProfile>[profile]);
    expect(metadata.values.values.single, isNot(contains('correct horse')));
    expect(
      await store.readPassword(profile.id),
      'correct horse battery staple',
    );
  });

  test('does not retain a password when rememberPassword is false', () async {
    final remembered = _profile(rememberPassword: true);
    await store.saveProfile(remembered);
    await store.writePassword(remembered, 'secret');

    final forgotten = remembered.copyWith(rememberPassword: false);
    await store.saveProfile(forgotten);
    await store.writePassword(forgotten, 'new-secret');

    expect(await store.readPassword(forgotten.id), isNull);
  });

  test('scopes certificate pins to the saved host and port', () async {
    final profile = _profile();
    final fingerprint = List<String>.filled(32, 'AB').join(':');

    await store.writeCertificatePin(profile, fingerprint);

    expect(await store.readCertificatePin(profile), fingerprint);
    expect(await store.readCertificatePin(profile.copyWith(port: 443)), isNull);
  });

  test('deleting a profile deletes its password and certificate pin', () async {
    final profile = _profile(rememberPassword: true);
    final fingerprint = List<String>.filled(32, 'CD').join(':');
    await store.saveProfile(profile);
    await store.writePassword(profile, 'secret');
    await store.writeCertificatePin(profile, fingerprint);

    await store.deleteProfile(profile.id);

    expect(await store.loadProfiles(), isEmpty);
    expect(await store.readPassword(profile.id), isNull);
    expect(await store.readCertificatePin(profile), isNull);
  });

  test('changing host or port removes the previous saved password', () async {
    for (final changed in <ConnectionProfile>[
      _profile(rememberPassword: true).copyWith(host: 'other.example.test'),
      _profile(rememberPassword: true).copyWith(port: 443),
    ]) {
      final profile = _profile(rememberPassword: true);
      await store.saveProfile(profile);
      await store.writePassword(profile, 'old-host-secret');
      await store.saveProfile(changed);
      expect(await store.readPassword(profile.id), isNull);
    }
  });

  test('does not save a new identity if old secret cleanup fails', () async {
    final profile = _profile(rememberPassword: true);
    await store.saveProfile(profile);
    await store.writePassword(profile, 'old-host-secret');
    secrets.failDeletion = true;

    await expectLater(
      store.saveProfile(profile.copyWith(host: 'other.example.test')),
      throwsA(isA<PveStorageException>()),
    );

    expect(await store.loadProfiles(), <ConnectionProfile>[profile]);
  });
}

ConnectionProfile _profile({bool rememberPassword = false}) {
  return ConnectionProfile(
    id: 'connection-one',
    name: 'Lab',
    host: 'pve.example.test',
    username: 'operator',
    rememberPassword: rememberPassword,
  );
}

class _MemoryMetadataStore implements ProfileMetadataStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _MemorySecretStore implements SecretStore {
  final Map<String, String> values = <String, String>{};
  bool failDeletion = false;

  @override
  Future<void> delete(String key) async {
    if (failDeletion) throw StateError('Secret storage unavailable');
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
