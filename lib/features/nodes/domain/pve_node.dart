enum PveNodeStatus { online, offline, unknown }

enum PveNodeAction { shutdown, reboot }

class PveNode {
  const PveNode({
    required this.connectionId,
    required this.name,
    required this.status,
    required this.cpuUsage,
    required this.maxCpu,
    required this.memoryBytes,
    required this.maxMemoryBytes,
    required this.diskBytes,
    required this.maxDiskBytes,
    required this.uptimeSeconds,
  });

  final String connectionId;
  final String name;
  final PveNodeStatus status;
  final double cpuUsage;
  final int maxCpu;
  final int memoryBytes;
  final int maxMemoryBytes;
  final int diskBytes;
  final int maxDiskBytes;
  final int uptimeSeconds;

  String get stableId => '$connectionId:$name';
  String get permissionPath => '/nodes/$name';
  bool get isOnline => status == PveNodeStatus.online;

  factory PveNode.fromClusterJson({
    required String connectionId,
    required Map<String, Object?> json,
  }) {
    final name = json['node']?.toString() ?? '';
    if (name.isEmpty) {
      throw const FormatException('Missing or invalid node.');
    }
    return PveNode(
      connectionId: connectionId,
      name: name,
      status: switch (json['status']?.toString().toLowerCase()) {
        'online' => PveNodeStatus.online,
        'offline' => PveNodeStatus.offline,
        _ => PveNodeStatus.unknown,
      },
      cpuUsage: _double(json['cpu']),
      maxCpu: _integer(json['maxcpu']),
      memoryBytes: _integer(json['mem']),
      maxMemoryBytes: _integer(json['maxmem']),
      diskBytes: _integer(json['disk']),
      maxDiskBytes: _integer(json['maxdisk']),
      uptimeSeconds: _integer(json['uptime']),
    );
  }

  static int _integer(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
