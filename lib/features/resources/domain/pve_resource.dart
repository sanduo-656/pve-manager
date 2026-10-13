enum PveResourceType { qemu, lxc }

enum PveResourceStatus { running, stopped, paused, suspended, unknown }

enum PveResourceAction { start, shutdown, reboot }

class PveResource {
  const PveResource({
    required this.connectionId,
    required this.node,
    required this.vmId,
    required this.name,
    required this.type,
    required this.status,
    required this.cpuUsage,
    required this.maxCpu,
    required this.memoryBytes,
    required this.maxMemoryBytes,
    required this.uptimeSeconds,
    this.isTemplate = false,
    this.lock,
  });

  final String connectionId;
  final String node;
  final int vmId;
  final String name;
  final PveResourceType type;
  final PveResourceStatus status;
  final double cpuUsage;
  final int maxCpu;
  final int memoryBytes;
  final int maxMemoryBytes;
  final int uptimeSeconds;
  final bool isTemplate;
  final String? lock;

  int get vmid => vmId;
  String get stableId => '$connectionId:${type.name}:$vmId';
  String get displayName => name.isEmpty ? '${type.name} $vmId' : name;
  bool get isRunning => status == PveResourceStatus.running;
  String get permissionPath => '/vms/$vmId';

  factory PveResource.fromClusterJson({
    required String connectionId,
    required Map<String, Object?> json,
  }) {
    final typeValue = json['type']?.toString();
    final type = switch (typeValue) {
      'qemu' => PveResourceType.qemu,
      'lxc' => PveResourceType.lxc,
      _ => throw FormatException('Unsupported resource type: $typeValue'),
    };
    final vmId = _requiredInt(json['vmid'], 'vmid');

    return PveResource(
      connectionId: connectionId,
      node: json['node']?.toString() ?? '',
      vmId: vmId,
      name: json['name']?.toString() ?? '',
      type: type,
      status: _parseStatus(json['status']),
      cpuUsage: _double(json['cpu']),
      maxCpu: _integer(json['maxcpu']),
      memoryBytes: _integer(json['mem']),
      maxMemoryBytes: _integer(json['maxmem']),
      uptimeSeconds: _integer(json['uptime']),
      isTemplate: _integer(json['template']) == 1,
      lock: json['lock']?.toString(),
    );
  }

  static PveResourceStatus _parseStatus(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'running' => PveResourceStatus.running,
      'stopped' => PveResourceStatus.stopped,
      'paused' => PveResourceStatus.paused,
      'suspended' => PveResourceStatus.suspended,
      _ => PveResourceStatus.unknown,
    };
  }

  static int _requiredInt(Object? value, String field) {
    final parsed = _integer(value, fallback: -1);
    if (parsed < 0) {
      throw FormatException('Missing or invalid $field.');
    }
    return parsed;
  }

  static int _integer(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _double(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
