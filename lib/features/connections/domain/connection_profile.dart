class ConnectionProfile {
  ConnectionProfile({
    required this.id,
    required this.name,
    required String host,
    this.port = 8006,
    required this.username,
    this.realm = 'pve',
    this.rememberPassword = false,
  }) : host = _normalizeHost(host) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    if (this.host.isEmpty) {
      throw ArgumentError.value(host, 'host', 'Must not be empty.');
    }
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'Must be between 1 and 65535.');
    }
    if (username.trim().isEmpty) {
      throw ArgumentError.value(username, 'username', 'Must not be empty.');
    }
    if (!username.contains('@') && realm.trim().isEmpty) {
      throw ArgumentError.value(realm, 'realm', 'Must not be empty.');
    }
  }

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String realm;
  final bool rememberPassword;

  String get userId => username.contains('@') ? username : '$username@$realm';

  String get authority =>
      Uri(scheme: 'https', host: host, port: port).authority;

  Uri get origin => Uri(scheme: 'https', host: host, port: port);

  Uri get apiBaseUri => origin.replace(path: '/api2/json/');

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? realm,
    bool? rememberPassword,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      realm: realm ?? this.realm,
      rememberPassword: rememberPassword ?? this.rememberPassword,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'realm': realm,
      'rememberPassword': rememberPassword,
    };
  }

  factory ConnectionProfile.fromJson(Map<String, Object?> json) {
    return ConnectionProfile(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      host: _requiredString(json, 'host'),
      port: _integer(json['port'], fallback: 8006),
      username: _requiredString(json, 'username'),
      realm: (json['realm'] as String?) ?? 'pve',
      rememberPassword: json['rememberPassword'] == true,
    );
  }

  static String _normalizeHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) {
      return trimmed.replaceAll(RegExp(r'^\[|\]$'), '');
    }
    return uri.host;
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid $key.');
    }
    return value;
  }

  static int _integer(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionProfile &&
        id == other.id &&
        name == other.name &&
        host == other.host &&
        port == other.port &&
        username == other.username &&
        realm == other.realm &&
        rememberPassword == other.rememberPassword;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, host, port, username, realm, rememberPassword);
}
