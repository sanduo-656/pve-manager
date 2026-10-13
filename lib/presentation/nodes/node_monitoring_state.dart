import '../../features/nodes/domain/pve_node_metrics.dart';

/// Each monitoring endpoint keeps its own data, timestamp and failure state.
class NodeMonitoringState {
  const NodeMonitoringState({
    this.snapshot,
    this.points = const [],
    this.storages = const [],
    this.timeframe = PveNodeTimeframe.hour,
    this.snapshotUpdatedAt,
    this.historyUpdatedAt,
    this.storageUpdatedAt,
    this.snapshotError,
    this.historyError,
    this.storageError,
    this.isLoadingSnapshot = false,
    this.isLoadingHistory = false,
    this.isLoadingStorage = false,
    this.isStale = false,
  });

  final PveNodeMetricsSnapshot? snapshot;
  final List<PveNodeRrdPoint> points;
  final List<PveStorageStatus> storages;
  final PveNodeTimeframe timeframe;
  final DateTime? snapshotUpdatedAt;
  final DateTime? historyUpdatedAt;
  final DateTime? storageUpdatedAt;
  final String? snapshotError;
  final String? historyError;
  final String? storageError;
  final bool isLoadingSnapshot;
  final bool isLoadingHistory;
  final bool isLoadingStorage;
  final bool isStale;

  NodeMonitoringState copyWith({
    PveNodeMetricsSnapshot? snapshot,
    List<PveNodeRrdPoint>? points,
    List<PveStorageStatus>? storages,
    PveNodeTimeframe? timeframe,
    DateTime? snapshotUpdatedAt,
    DateTime? historyUpdatedAt,
    DateTime? storageUpdatedAt,
    String? snapshotError,
    String? historyError,
    String? storageError,
    bool? isLoadingSnapshot,
    bool? isLoadingHistory,
    bool? isLoadingStorage,
    bool? isStale,
    bool clearHistory = false,
    bool clearSnapshotError = false,
    bool clearHistoryError = false,
    bool clearStorageError = false,
  }) => NodeMonitoringState(
    snapshot: snapshot ?? this.snapshot,
    points: points ?? (clearHistory ? const [] : this.points),
    storages: storages ?? this.storages,
    timeframe: timeframe ?? this.timeframe,
    snapshotUpdatedAt: snapshotUpdatedAt ?? this.snapshotUpdatedAt,
    historyUpdatedAt: clearHistory
        ? null
        : historyUpdatedAt ?? this.historyUpdatedAt,
    storageUpdatedAt: storageUpdatedAt ?? this.storageUpdatedAt,
    snapshotError: clearSnapshotError
        ? null
        : snapshotError ?? this.snapshotError,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    storageError: clearStorageError ? null : storageError ?? this.storageError,
    isLoadingSnapshot: isLoadingSnapshot ?? this.isLoadingSnapshot,
    isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
    isLoadingStorage: isLoadingStorage ?? this.isLoadingStorage,
    isStale: isStale ?? this.isStale,
  );
}
