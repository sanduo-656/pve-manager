enum PveNodeTimeframe { hour, day, week, month, year }

/// Current node status. Unknown metrics stay null rather than appearing as zero.
class PveNodeMetricsSnapshot {
  const PveNodeMetricsSnapshot({
    this.cpuUsage,
    this.ioWait,
    this.cpuCount,
    this.cpuModel,
    this.memoryUsedBytes,
    this.memoryTotalBytes,
    this.memoryAvailableBytes,
    this.swapUsedBytes,
    this.swapTotalBytes,
    this.rootfsUsedBytes,
    this.rootfsTotalBytes,
    this.rootfsAvailableBytes,
    this.uptimeSeconds,
    this.pveVersion,
    this.loadAverage = const <double>[],
  });

  /// CPU usage and I/O wait are fractions, as returned by Proxmox.
  final double? cpuUsage;
  final double? ioWait;
  final int? cpuCount;
  final String? cpuModel;
  final int? memoryUsedBytes;
  final int? memoryTotalBytes;
  final int? memoryAvailableBytes;
  final int? swapUsedBytes;
  final int? swapTotalBytes;
  final int? rootfsUsedBytes;
  final int? rootfsTotalBytes;
  final int? rootfsAvailableBytes;
  final int? uptimeSeconds;
  final String? pveVersion;

  /// Load averages for 1, 5 and 15 minutes, when supplied by the server.
  final List<double> loadAverage;

  factory PveNodeMetricsSnapshot.fromJson(Map<String, Object?> json) {
    final cpuInfo = _nestedMap(json['cpuinfo']);
    final memory = _nestedMap(json['memory']);
    final swap = _nestedMap(json['swap']);
    final rootfs = _nestedMap(json['rootfs']);
    return PveNodeMetricsSnapshot(
      cpuUsage: _finiteDouble(json['cpu']),
      ioWait: _finiteDouble(json['wait']),
      cpuCount: _integer(cpuInfo['cpus']),
      cpuModel: _optionalString(cpuInfo['model']),
      memoryUsedBytes: _integer(memory['used']),
      memoryTotalBytes: _integer(memory['total']),
      memoryAvailableBytes: _integer(memory['available']),
      swapUsedBytes: _integer(swap['used']),
      swapTotalBytes: _integer(swap['total']),
      rootfsUsedBytes: _integer(rootfs['used']),
      rootfsTotalBytes: _integer(rootfs['total']),
      rootfsAvailableBytes: _integer(rootfs['avail']),
      uptimeSeconds: _integer(json['uptime']),
      pveVersion: _optionalString(json['pveversion']),
      loadAverage: _loadAverage(json['loadavg']),
    );
  }
}

/// A native RRD sample. A sample without metrics is retained as a chart gap.
class PveNodeRrdPoint {
  const PveNodeRrdPoint({
    required this.time,
    this.cpuUsage,
    this.ioWait,
    this.loadAverage,
    this.memoryUsedBytes,
    this.memoryTotalBytes,
    this.memoryAvailableBytes,
    this.swapUsedBytes,
    this.swapTotalBytes,
    this.rootfsUsedBytes,
    this.rootfsTotalBytes,
    this.netInBytesPerSecond,
    this.netOutBytesPerSecond,
  });

  final DateTime time;
  final double? cpuUsage;
  final double? ioWait;
  final double? loadAverage;
  final double? memoryUsedBytes;
  final double? memoryTotalBytes;
  final double? memoryAvailableBytes;
  final double? swapUsedBytes;
  final double? swapTotalBytes;
  final double? rootfsUsedBytes;
  final double? rootfsTotalBytes;

  /// Proxmox RRD has already converted network counters to bytes per second.
  final double? netInBytesPerSecond;
  final double? netOutBytesPerSecond;

  factory PveNodeRrdPoint.fromJson(Map<String, Object?> json) {
    final seconds = _finiteDouble(json['time']);
    // Dart DateTime supports at most 100,000,000 days from the Unix epoch.
    if (seconds == null || seconds.abs() > 8640000000000) {
      throw const FormatException('Missing or invalid RRD sample time.');
    }
    return PveNodeRrdPoint(
      time: DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      ),
      cpuUsage: _finiteDouble(json['cpu']),
      ioWait: _finiteDouble(json['iowait']),
      loadAverage: _finiteDouble(json['loadavg']),
      memoryUsedBytes: _finiteDouble(json['memused']),
      memoryTotalBytes: _finiteDouble(json['memtotal']),
      memoryAvailableBytes: _finiteDouble(json['memavailable']),
      swapUsedBytes: _finiteDouble(json['swapused']),
      swapTotalBytes: _finiteDouble(json['swaptotal']),
      rootfsUsedBytes: _finiteDouble(json['rootused']),
      rootfsTotalBytes: _finiteDouble(json['roottotal']),
      netInBytesPerSecond: _finiteDouble(json['netin']),
      netOutBytesPerSecond: _finiteDouble(json['netout']),
    );
  }
}

class PveStorageStatus {
  const PveStorageStatus({
    required this.id,
    required this.type,
    this.isActive,
    this.isEnabled,
    this.isShared,
    this.usedBytes,
    this.totalBytes,
    this.availableBytes,
  });

  final String id;
  final String type;
  final bool? isActive;
  final bool? isEnabled;
  final bool? isShared;
  final int? usedBytes;
  final int? totalBytes;
  final int? availableBytes;

  factory PveStorageStatus.fromJson(Map<String, Object?> json) {
    return PveStorageStatus(
      id: _requiredString(json['storage'], 'storage'),
      type: _requiredString(json['type'], 'storage type'),
      isActive: _boolean(json['active']),
      isEnabled: _boolean(json['enabled']),
      isShared: _boolean(json['shared']),
      usedBytes: _integer(json['used']),
      totalBytes: _integer(json['total']),
      availableBytes: _integer(json['avail']),
    );
  }
}

Map<String, Object?> _nestedMap(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

double? _finiteDouble(Object? value) {
  final number = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value)
      : null;
  return number != null && number.isFinite ? number : null;
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is String) {
    final integer = int.tryParse(value);
    if (integer != null) return integer;
  }
  return _finiteDouble(value)?.toInt();
}

String? _optionalString(Object? value) {
  return value is String && value.trim().isNotEmpty ? value : null;
}

String _requiredString(Object? value, String field) {
  final string = _optionalString(value);
  if (string == null) throw FormatException('Missing or invalid $field.');
  return string;
}

bool? _boolean(Object? value) {
  if (value == true || value == 1 || value == '1' || value == 'true') {
    return true;
  }
  if (value == false || value == 0 || value == '0' || value == 'false') {
    return false;
  }
  return null;
}

List<double> _loadAverage(Object? value) {
  if (value is! List) return const <double>[];
  final averages = <double>[];
  for (final item in value) {
    final average = _finiteDouble(item);
    // Preserve the 1/5/15-minute positions; dropping an invalid item shifts them.
    if (average == null) return const <double>[];
    averages.add(average);
  }
  return List<double>.unmodifiable(averages);
}
