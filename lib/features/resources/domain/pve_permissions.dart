class PvePermissions {
  PvePermissions({
    required String connectionId,
    required Map<String, Set<String>> privilegesByPath,
  }) : this._(
         connectionId: connectionId,
         permissionsByPath: privilegesByPath.map(
           (path, privileges) => MapEntry(path, <String, bool>{
             for (final privilege in privileges) privilege: true,
           }),
         ),
       );

  PvePermissions._({
    required this.connectionId,
    required Map<String, Map<String, bool>> permissionsByPath,
  }) : _permissionsByPath = Map<String, Map<String, bool>>.unmodifiable(
         permissionsByPath.map(
           (path, privileges) => MapEntry(
             _normalizePath(path),
             Map<String, bool>.unmodifiable(privileges),
           ),
         ),
       );

  final String connectionId;
  final Map<String, Map<String, bool>> _permissionsByPath;

  Map<String, Set<String>> get privilegesByPath =>
      Map<String, Set<String>>.unmodifiable(
        _permissionsByPath.map(
          (path, privileges) =>
              MapEntry(path, Set<String>.unmodifiable(privileges.keys)),
        ),
      );

  factory PvePermissions.fromApiJson({
    required String connectionId,
    required Map<String, Object?> json,
  }) {
    final result = <String, Map<String, bool>>{};
    for (final entry in json.entries) {
      final rawPrivileges = entry.value;
      if (rawPrivileges is! Map) {
        continue;
      }
      final privileges = <String, bool>{};
      for (final privilege in rawPrivileges.entries) {
        if (_isPermissionValue(privilege.value)) {
          privileges[privilege.key.toString()] = _propagates(privilege.value);
        }
      }
      result[entry.key] = privileges;
    }
    return PvePermissions._(
      connectionId: connectionId,
      permissionsByPath: result,
    );
  }

  bool allows(String privilege, String path) {
    final requestedPath = _normalizePath(path);
    var candidate = requestedPath;
    while (true) {
      final permissions = _permissionsByPath[candidate];
      final propagation = permissions?[privilege];
      if (propagation != null) {
        return candidate == requestedPath || propagation;
      }
      if (candidate == '/') {
        return false;
      }
      final separator = candidate.lastIndexOf('/');
      candidate = separator <= 0 ? '/' : candidate.substring(0, separator);
    }
  }

  bool propagates(String privilege, String path) {
    return _permissionsByPath[_normalizePath(path)]?[privilege] == true;
  }

  bool canAuditResource(int vmId) => allows('VM.Audit', '/vms/$vmId');
  bool canPowerResource(int vmId) => allows('VM.PowerMgmt', '/vms/$vmId');
  bool canOpenConsole(int vmId) => allows('VM.Console', '/vms/$vmId');
  bool canAuditNode(String node) => allows('Sys.Audit', '/nodes/$node');
  bool canPowerNode(String node) => allows('Sys.PowerMgmt', '/nodes/$node');

  static bool _isPermissionValue(Object? value) {
    return value == true ||
        value == false ||
        value == 1 ||
        value == 0 ||
        value == '1' ||
        value == '0';
  }

  static bool _propagates(Object? value) {
    return value == true || value == 1 || value == '1';
  }

  static String _normalizePath(String value) {
    var path = value.trim();
    if (path.isEmpty || path == '/') {
      return '/';
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    while (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }
}
