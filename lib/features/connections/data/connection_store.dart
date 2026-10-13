import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/pve_exception.dart';
import '../../../core/network/certificate_fingerprint.dart';
import '../domain/connection_profile.dart';

abstract interface class ProfileMetadataStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class SharedPreferencesProfileMetadataStore
    implements ProfileMetadataStore {
  SharedPreferencesProfileMetadataStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}

final class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore([FlutterSecureStorage? storage])
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class ConnectionStore {
  ConnectionStore({
    ProfileMetadataStore? metadataStore,
    SecretStore? secretStore,
  }) : _metadata = metadataStore ?? SharedPreferencesProfileMetadataStore(),
       _secrets = secretStore ?? FlutterSecureSecretStore();

  static const String _profilesKey = 'pve.connection_profiles.v1';
  static const String _secretPrefix = 'pve.connection';

  final ProfileMetadataStore _metadata;
  final SecretStore _secrets;

  Future<List<ConnectionProfile>> loadProfiles() async {
    try {
      final encoded = await _metadata.read(_profilesKey);
      if (encoded == null || encoded.isEmpty) {
        return const <ConnectionProfile>[];
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        throw const FormatException('Profiles must be a JSON list.');
      }
      return List<ConnectionProfile>.unmodifiable(
        decoded.map((value) {
          if (value is! Map) {
            throw const FormatException('A profile must be a JSON object.');
          }
          return ConnectionProfile.fromJson(
            value.map((key, item) => MapEntry(key.toString(), item)),
          );
        }),
      );
    } catch (error) {
      if (error is PveStorageException) {
        rethrow;
      }
      throw PveStorageException(
        'Unable to read saved connection profiles.',
        cause: error,
      );
    }
  }

  Future<void> saveProfile(ConnectionProfile profile) async {
    try {
      final profiles = (await loadProfiles()).toList();
      final index = profiles.indexWhere((item) => item.id == profile.id);
      final previous = index < 0 ? null : profiles[index];
      if (index < 0) {
        profiles.add(profile);
      } else {
        profiles[index] = profile;
      }
      if (!profile.rememberPassword ||
          (previous != null &&
              (previous.userId != profile.userId ||
                  previous.authority != profile.authority))) {
        await deletePassword(profile.id);
      }
      if (previous != null && previous.authority != profile.authority) {
        await deleteCertificatePin(profile.id);
      }
      await _metadata.write(
        _profilesKey,
        jsonEncode(profiles.map((item) => item.toJson()).toList()),
      );
    } catch (error) {
      if (error is PveStorageException) {
        rethrow;
      }
      throw PveStorageException(
        'Unable to save the connection profile.',
        cause: error,
      );
    }
  }

  Future<void> deleteProfile(String connectionId) async {
    try {
      final profiles = (await loadProfiles())
          .where((profile) => profile.id != connectionId)
          .toList();
      await _metadata.write(
        _profilesKey,
        jsonEncode(profiles.map((item) => item.toJson()).toList()),
      );
      await deletePassword(connectionId);
      await deleteCertificatePin(connectionId);
    } catch (error) {
      if (error is PveStorageException) {
        rethrow;
      }
      throw PveStorageException(
        'Unable to delete the connection profile.',
        cause: error,
      );
    }
  }

  Future<String?> readPassword(String connectionId) {
    return _readSecret(_passwordKey(connectionId), 'password');
  }

  Future<void> writePassword(ConnectionProfile profile, String password) async {
    if (!profile.rememberPassword) {
      await deletePassword(profile.id);
      return;
    }
    await _writeSecret(_passwordKey(profile.id), password, 'password');
  }

  Future<void> deletePassword(String connectionId) {
    return _deleteSecret(_passwordKey(connectionId), 'password');
  }

  Future<String?> readCertificatePin(ConnectionProfile profile) async {
    final encoded = await _readSecret(_pinKey(profile.id), 'certificate pin');
    if (encoded == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map || decoded['authority'] != profile.authority) {
        return null;
      }
      final fingerprint = decoded['fingerprint'];
      if (fingerprint is! String) {
        throw const FormatException('Missing certificate fingerprint.');
      }
      return CertificateFingerprint.normalize(fingerprint);
    } catch (error) {
      throw PveStorageException(
        'Unable to read the saved certificate pin.',
        cause: error,
      );
    }
  }

  Future<void> writeCertificatePin(
    ConnectionProfile profile,
    String fingerprint,
  ) async {
    final normalized = CertificateFingerprint.normalize(fingerprint);
    final value = jsonEncode(<String, String>{
      'authority': profile.authority,
      'fingerprint': normalized,
    });
    await _writeSecret(_pinKey(profile.id), value, 'certificate pin');
  }

  Future<void> deleteCertificatePin(String connectionId) {
    return _deleteSecret(_pinKey(connectionId), 'certificate pin');
  }

  Future<String?> _readSecret(String key, String label) async {
    try {
      return await _secrets.read(key);
    } catch (error) {
      throw PveStorageException(
        'Unable to read the saved $label.',
        cause: error,
      );
    }
  }

  Future<void> _writeSecret(String key, String value, String label) async {
    try {
      await _secrets.write(key, value);
    } catch (error) {
      throw PveStorageException('Unable to save the $label.', cause: error);
    }
  }

  Future<void> _deleteSecret(String key, String label) async {
    try {
      await _secrets.delete(key);
    } catch (error) {
      throw PveStorageException('Unable to delete the $label.', cause: error);
    }
  }

  static String _passwordKey(String connectionId) =>
      '$_secretPrefix.$connectionId.password';

  static String _pinKey(String connectionId) =>
      '$_secretPrefix.$connectionId.certificate_pin';
}
