enum PveTaskStatus { running, stopped, unknown }

class PveTask {
  const PveTask({
    required this.connectionId,
    required this.node,
    required this.upid,
    required this.status,
    this.exitStatus,
  });

  final String connectionId;
  final String node;
  final String upid;
  final PveTaskStatus status;
  final String? exitStatus;

  bool get isComplete => status == PveTaskStatus.stopped;
  bool get succeeded => isComplete && exitStatus == 'OK';

  factory PveTask.pending({
    required String connectionId,
    required String node,
    required String upid,
  }) {
    return PveTask(
      connectionId: connectionId,
      node: node,
      upid: upid,
      status: PveTaskStatus.running,
    );
  }

  PveTask withStatusJson(Map<String, Object?> json) {
    return PveTask(
      connectionId: connectionId,
      node: node,
      upid: upid,
      status: switch (json['status']?.toString()) {
        'running' => PveTaskStatus.running,
        'stopped' => PveTaskStatus.stopped,
        _ => PveTaskStatus.unknown,
      },
      exitStatus: json['exitstatus']?.toString(),
    );
  }
}
