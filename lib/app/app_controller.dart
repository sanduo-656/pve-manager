import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/pve_exception.dart';
import '../core/network/pve_api_client.dart';
import '../features/connections/data/connection_store.dart';
import '../features/connections/domain/connection_profile.dart';
import '../features/connections/domain/pve_session.dart';
import '../features/nodes/domain/pve_node.dart';
import '../features/nodes/domain/pve_node_metrics.dart';
import '../features/resources/domain/pve_permissions.dart';
import '../features/resources/domain/pve_resource.dart';
import '../presentation/view_models.dart';
import '../presentation/nodes/node_monitoring_state.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  return AppController()..initialize();
});

sealed class ConnectionFlowResult {
  const ConnectionFlowResult();
}

final class ConnectionFlowSucceeded extends ConnectionFlowResult {
  const ConnectionFlowSucceeded({required this.saved});

  final bool saved;
}

final class ConnectionFlowNeedsTotp extends ConnectionFlowResult {
  const ConnectionFlowNeedsTotp({required this.availableMethods});

  final Set<String> availableMethods;
}

final class ConnectionFlowNeedsCertificate extends ConnectionFlowResult {
  const ConnectionFlowNeedsCertificate({required this.prompt});

  final CertificatePromptViewModel prompt;
}

final class ConnectionFlowFailed extends ConnectionFlowResult {
  const ConnectionFlowFailed(this.message);

  final String message;
}

class ConsoleLaunch {
  const ConsoleLaunch({
    required this.title,
    required this.origin,
    required this.ticket,
    required this.consoleType,
    required this.node,
    required this.vmid,
    this.pinnedSha256,
  });

  final String title;
  final String origin;
  final String ticket;
  final String consoleType;
  final String node;
  final int vmid;
  final String? pinnedSha256;
}

class AppController extends ChangeNotifier {
  AppController({
    ConnectionStore? store,
    DateTime Function()? now,
    PveApiClient Function(ConnectionProfile profile, String? pin)?
    clientFactory,
  }) : _store = store ?? ConnectionStore(),
       _now = now ?? DateTime.now,
       _clientFactory = clientFactory ?? _defaultClientFactory;

  final ConnectionStore _store;
  final DateTime Function() _now;
  final Map<String, NodeMonitoringState> _nodeMonitoring = {};
  final Map<String, Object> _monitoringRequests = {};
  final Map<String, DateTime> _monitoringAttempts = {};
  final PveApiClient Function(ConnectionProfile profile, String? pin)
  _clientFactory;

  static PveApiClient _defaultClientFactory(
    ConnectionProfile profile,
    String? pin,
  ) => PveApiClient(profile: profile, pinnedCertificateFingerprint: pin);
  final Map<String, PveApiClient> _clients = <String, PveApiClient>{};
  final Map<String, int> _clientGenerations = <String, int>{};
  final Map<String, PveSession> _sessions = <String, PveSession>{};
  final Map<String, List<PveResource>> _resources =
      <String, List<PveResource>>{};
  final Map<String, List<PveNode>> _nodes = <String, List<PveNode>>{};
  final Map<String, PvePermissions> _permissions = <String, PvePermissions>{};
  final Map<String, ConnectionStatus> _connectionStatuses =
      <String, ConnectionStatus>{};
  final Map<String, String> _connectionDetails = <String, String>{};
  final Map<String, String?> _certificatePins = <String, String?>{};
  final Map<String, PveCertificateException> _certificateErrors =
      <String, PveCertificateException>{};
  final Map<String, ResourcePowerAction> _resourceActions =
      <String, ResourcePowerAction>{};
  final Map<String, NodePowerAction> _nodeActions = <String, NodePowerAction>{};
  final Map<String, Object> _operationTokens = <String, Object>{};
  final Map<String, String> _operationMessages = <String, String>{};

  final Uuid _uuid = const Uuid();
  List<ConnectionProfile> _profiles = <ConnectionProfile>[];
  AppSection _section = AppSection.resources;
  ResourceFilterViewModel _resourceFilter = const ResourceFilterViewModel();
  NodeFilterViewModel _nodeFilter = const NodeFilterViewModel();
  String? _selectedResourceId;
  String? _selectedNodeId;
  bool _initializing = true;
  bool _refreshing = false;
  bool _foreground = true;
  bool _disposed = false;
  Timer? _refreshTimer;
  _PendingConnection? _pendingConnection;
  int _pendingGeneration = 0;
  final Map<String, DateTime> _lastUpdatedAt = {};
  Future<void> _connectionWrites = Future<void>.value();
  PveApiClient? _pendingClient;
  String? _pendingClientPin;
  PveCertificateException? _pendingCertificateError;
  String? _pendingTotpChallenge;
  String? _approvedPendingPin;
  String? _notice;
  bool _noticeIsError = false;
  int _noticeSerial = 0;

  List<ConnectionProfile> get profiles => List.unmodifiable(_profiles);
  AppSection get section => _section;
  ResourceFilterViewModel get resourceFilter => _resourceFilter;
  NodeFilterViewModel get nodeFilter => _nodeFilter;
  String? get selectedResourceId => _selectedResourceId;
  String? get selectedNodeId => _selectedNodeId;
  bool get isInitializing => _initializing;
  bool get isRefreshing => _refreshing;
  String? get notice => _notice;
  bool get noticeIsError => _noticeIsError;
  int get noticeSerial => _noticeSerial;

  DateTime? lastUpdatedAtFor(String? connectionId) {
    final values = _profiles
        .where((p) => connectionId == null || p.id == connectionId)
        .map((p) => _lastUpdatedAt[p.id])
        .whereType<DateTime>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  bool connectionIsOnline(String? connectionId) {
    final profiles = _profiles
        .where((p) => connectionId == null || p.id == connectionId)
        .toList();
    return profiles.isNotEmpty &&
        profiles.every(
          (p) => _connectionStatuses[p.id] == ConnectionStatus.connected,
        );
  }

  List<ConnectionOptionViewModel> get connectionOptions => _profiles
      .map(
        (profile) =>
            ConnectionOptionViewModel(id: profile.id, name: profile.name),
      )
      .toList(growable: false);

  List<ConnectionViewModel> get connectionViewModels => _profiles
      .map((profile) {
        final status =
            _connectionStatuses[profile.id] ?? ConnectionStatus.unknown;
        final pin = _certificatePins[profile.id];
        final certificateError = _certificateErrors[profile.id];
        final certificateStatus =
            certificateError is PveCertificateMismatchException
            ? CertificateStatus.changed
            : certificateError != null
            ? CertificateStatus.untrusted
            : pin != null
            ? CertificateStatus.pinned
            : status == ConnectionStatus.connected
            ? CertificateStatus.systemTrusted
            : CertificateStatus.unknown;
        return ConnectionViewModel(
          id: profile.id,
          name: profile.name,
          host: profile.host,
          port: profile.port,
          username: profile.username,
          realm: profile.realm,
          status: status,
          certificateStatus: certificateStatus,
          rememberPassword: profile.rememberPassword,
          detail: _connectionDetails[profile.id],
        );
      })
      .toList(growable: false);

  List<ResourceViewModel> get resourceViewModels {
    final result = <ResourceViewModel>[];
    for (final profile in _profiles) {
      final permissions = _permissions[profile.id];
      final connected = _canOperateConnection(profile.id);
      for (final resource in _resources[profile.id] ?? const <PveResource>[]) {
        result.add(
          ResourceViewModel(
            id: resource.stableId,
            connectionId: resource.connectionId,
            connectionName: profile.name,
            nodeName: resource.node,
            guestId: resource.vmId.toString(),
            name: resource.displayName,
            kind: resource.type == PveResourceType.qemu
                ? ResourceKind.qemu
                : ResourceKind.lxc,
            status: _resourceStatus(resource.status),
            cpuUsage: resource.cpuUsage,
            memoryUsedBytes: resource.memoryBytes,
            memoryTotalBytes: resource.maxMemoryBytes,
            capabilities: ResourceCapabilitiesViewModel(
              canAudit: permissions?.canAuditResource(resource.vmId) ?? true,
              canPower:
                  connected &&
                  !resource.isTemplate &&
                  resource.lock == null &&
                  (permissions?.canPowerResource(resource.vmId) ?? false),
              canConsole:
                  connected &&
                  !resource.isTemplate &&
                  resource.lock == null &&
                  (permissions?.canOpenConsole(resource.vmId) ?? false),
            ),
            activeAction: _resourceActions[resource.stableId],
            operationMessage: _operationMessages[resource.stableId],
          ),
        );
      }
    }
    result.sort((a, b) {
      final connection = a.connectionName.compareTo(b.connectionName);
      if (connection != 0) return connection;
      return a.guestId.compareTo(b.guestId);
    });
    return result;
  }

  List<NodeViewModel> get nodeViewModels {
    final result = <NodeViewModel>[];
    for (final profile in _profiles) {
      final permissions = _permissions[profile.id];
      for (final node in _nodes[profile.id] ?? const <PveNode>[]) {
        result.add(
          NodeViewModel(
            id: node.stableId,
            connectionId: node.connectionId,
            connectionName: profile.name,
            name: node.name,
            status: switch (node.status) {
              PveNodeStatus.online => NodeStatus.online,
              PveNodeStatus.offline => NodeStatus.offline,
              PveNodeStatus.unknown => NodeStatus.unknown,
            },
            cpuUsage: node.cpuUsage,
            memoryUsedBytes: node.memoryBytes,
            memoryTotalBytes: node.maxMemoryBytes,
            uptime: Duration(seconds: node.uptimeSeconds),
            capabilities: NodeCapabilitiesViewModel(
              canAudit: permissions?.canAuditNode(node.name) ?? true,
              canPower:
                  _canOperateConnection(profile.id) &&
                  (permissions?.canPowerNode(node.name) ?? false),
            ),
            activeAction: _nodeActions[node.stableId],
            operationMessage: _operationMessages[node.stableId],
          ),
        );
      }
    }
    result.sort((a, b) {
      final connection = a.connectionName.compareTo(b.connectionName);
      return connection != 0 ? connection : a.name.compareTo(b.name);
    });
    return result;
  }

  ResourceViewModel? get selectedResource => _firstWhereOrNull(
    resourceViewModels,
    (item) => item.id == _selectedResourceId,
  );

  NodeViewModel? get selectedNode =>
      _firstWhereOrNull(nodeViewModels, (item) => item.id == _selectedNodeId);

  NodeMonitoringState? get selectedNodeMonitoring {
    final node = selectedNode;
    if (node == null) return null;
    final state = _nodeMonitoring[node.id] ?? const NodeMonitoringState();
    final sampledAt = state.snapshotUpdatedAt;
    return state.copyWith(
      isStale:
          !node.isOnline ||
          !_canOperateConnection(node.connectionId) ||
          (state.snapshot != null && state.snapshotError != null) ||
          (state.points.isNotEmpty && state.historyError != null) ||
          (state.storages.isNotEmpty && state.storageError != null) ||
          (sampledAt != null &&
              _now().difference(sampledAt) > const Duration(seconds: 45)),
    );
  }

  void setNodeMonitoringTimeframe(PveNodeTimeframe value) {
    final node = selectedNode;
    if (node == null) return;
    final state = _nodeMonitoring[node.id] ?? const NodeMonitoringState();
    if (state.timeframe == value) return;
    _monitoringRequests.remove('${node.id}:history');
    _monitoringAttempts.remove('${node.id}:history');
    _nodeMonitoring[node.id] = state.copyWith(
      timeframe: value,
      clearHistory: true,
      clearHistoryError: true,
      isLoadingHistory: false,
    );
    _notify();
    unawaited(refreshNodeMonitoring(forceHistory: true));
  }

  /// Poll the visible node only. Optional endpoint failures stay local to it.
  Future<void> refreshNodeMonitoring({bool forceHistory = false}) async {
    if (_disposed || !_foreground || _section != AppSection.nodes) return;
    final node = selectedNode;
    if (node == null ||
        !node.isOnline ||
        !_canOperateConnection(node.connectionId)) {
      return;
    }
    final state = _nodeMonitoring[node.id] ?? const NodeMonitoringState();
    if (!node.capabilities.canAudit) return;
    final profile = profileById(node.connectionId);
    final client = _clients[node.connectionId];
    final generation = _clientGenerations[node.connectionId] ?? 0;
    if (profile == null || client == null) return;
    final sessionFuture = _freshSession(node.connectionId);
    final loads = <Future<void>>[];

    void load<T>(
      String part,
      Future<T> Function(PveSession) fetch,
      NodeMonitoringState Function(NodeMonitoringState, T, DateTime) apply,
    ) {
      final key = '${node.id}:$part';
      if (_monitoringRequests.containsKey(key)) return;
      final attemptedAt = _monitoringAttempts[key];
      if (part != 'snapshot' &&
          !forceHistory &&
          attemptedAt != null &&
          _now().difference(attemptedAt) < const Duration(minutes: 1)) {
        return;
      }
      loads.add(
        _loadNodeMonitoringPart<T>(
          node: node,
          profile: profile,
          client: client,
          generation: generation,
          part: part,
          sessionFuture: sessionFuture,
          fetch: fetch,
          apply: apply,
        ),
      );
    }

    load<PveNodeMetricsSnapshot>(
      'snapshot',
      (session) => client.fetchNodeMetrics(session, node: node.name),
      (current, snapshot, at) => current.copyWith(
        snapshot: snapshot,
        snapshotUpdatedAt: at,
        clearSnapshotError: true,
      ),
    );
    load<List<PveNodeRrdPoint>>(
      'history',
      (session) => client.fetchNodeHistory(
        session,
        node: node.name,
        timeframe: state.timeframe,
      ),
      (current, points, at) => current.copyWith(
        points: List.unmodifiable(points),
        historyUpdatedAt: at,
        clearHistoryError: true,
      ),
    );
    load<List<PveStorageStatus>>(
      'storage',
      (session) => client.fetchNodeStorages(session, node: node.name),
      (current, storages, at) => current.copyWith(
        storages: List.unmodifiable(storages),
        storageUpdatedAt: at,
        clearStorageError: true,
      ),
    );
    await Future.wait(loads);
  }

  Future<void> _loadNodeMonitoringPart<T>({
    required NodeViewModel node,
    required ConnectionProfile profile,
    required PveApiClient client,
    required int generation,
    required String part,
    required Future<PveSession?> sessionFuture,
    required Future<T> Function(PveSession) fetch,
    required NodeMonitoringState Function(NodeMonitoringState, T, DateTime)
    apply,
  }) async {
    final key = '${node.id}:$part';
    final token = Object();
    _monitoringRequests[key] = token;
    _monitoringAttempts[key] = _now();
    _setMonitoringLoading(node.id, part, true);
    _notify();
    bool isCurrent() =>
        identical(_monitoringRequests[key], token) &&
        _isActiveClient(profile, client, generation) &&
        _foreground &&
        _section == AppSection.nodes &&
        _selectedNodeId == node.id;
    try {
      final session = await sessionFuture;
      if (!isCurrent()) return;
      if (session == null) {
        // Session renewal already classified its error. Preserve network/TLS
        // failures instead of relabelling every missing session as a bad login.
        throw PveApiException(_connectionDetails[profile.id] ?? '需要重新登录 PVE。');
      }
      final value = await fetch(session);
      if (!isCurrent()) return;
      _nodeMonitoring[node.id] = apply(
        _nodeMonitoring[node.id] ?? const NodeMonitoringState(),
        value,
        _now(),
      );
    } on Object catch (error) {
      if (!isCurrent()) return;
      var current = _nodeMonitoring[node.id] ?? const NodeMonitoringState();
      final message = error is PvePermissionException
          ? (part == 'storage'
                ? '当前账号没有存储审计权限（Datastore.Audit）。'
                : '当前账号没有节点审计权限（Sys.Audit）。')
          : _friendlyError(error);
      current = switch (part) {
        'snapshot' => current.copyWith(snapshotError: message),
        'history' => current.copyWith(historyError: message),
        _ => current.copyWith(storageError: message),
      };
      _nodeMonitoring[node.id] = current;
      if (error is PveAuthenticationException ||
          error is PveCertificateException) {
        _connectionStatuses[profile.id] = _statusForError(error);
        _connectionDetails[profile.id] = _friendlyError(error);
        if (error is PveAuthenticationException) _sessions.remove(profile.id);
        if (error is PveCertificateException) {
          _certificateErrors[profile.id] = error;
        }
      }
    } finally {
      if (identical(_monitoringRequests[key], token)) {
        _monitoringRequests.remove(key);
        _setMonitoringLoading(node.id, part, false);
        _notify();
      }
    }
  }

  void _setMonitoringLoading(String nodeId, String part, bool loading) {
    final current = _nodeMonitoring[nodeId] ?? const NodeMonitoringState();
    _nodeMonitoring[nodeId] = switch (part) {
      'snapshot' => current.copyWith(isLoadingSnapshot: loading),
      'history' => current.copyWith(isLoadingHistory: loading),
      _ => current.copyWith(isLoadingStorage: loading),
    };
  }

  void _stopMonitoringRequests() {
    for (final key in _monitoringRequests.keys) {
      _monitoringAttempts.remove(key);
    }
    _monitoringRequests.clear();
    _nodeMonitoring.updateAll(
      (_, state) => state.copyWith(
        isLoadingSnapshot: false,
        isLoadingHistory: false,
        isLoadingStorage: false,
      ),
    );
  }

  void _clearConnectionMonitoring(String connectionId) {
    final prefix = '$connectionId:';
    _nodeMonitoring.removeWhere((key, _) => key.startsWith(prefix));
    _monitoringRequests.removeWhere((key, _) => key.startsWith(prefix));
    _monitoringAttempts.removeWhere((key, _) => key.startsWith(prefix));
  }

  void _clearConnectionOperations(String connectionId) {
    final prefix = '$connectionId:';
    _resourceActions.removeWhere((key, _) => key.startsWith(prefix));
    _nodeActions.removeWhere((key, _) => key.startsWith(prefix));
    _operationTokens.removeWhere((key, _) => key.startsWith(prefix));
    _operationMessages.removeWhere((key, _) => key.startsWith(prefix));
  }

  PaneStateViewModel get resourcesPaneState {
    if (_initializing) {
      return const PaneStateViewModel.loading(message: '正在读取连接…');
    }
    if (_profiles.isEmpty) {
      return const PaneStateViewModel.empty(
        title: '还没有 PVE 连接',
        message: '添加第一个连接后即可查看资源。',
        actionLabel: '添加连接',
      );
    }
    if (_sessions.isEmpty) {
      return const PaneStateViewModel.authenticationRequired(
        message: '请在“连接”中登录至少一台 PVE。',
      );
    }
    return const PaneStateViewModel();
  }

  PaneStateViewModel get nodesPaneState => resourcesPaneState;

  PaneStateViewModel get connectionsPaneState => _initializing
      ? const PaneStateViewModel.loading(message: '正在读取连接…')
      : const PaneStateViewModel();

  List<ScopedErrorViewModel> get partialErrors {
    return _profiles
        .where((profile) {
          final status = _connectionStatuses[profile.id];
          return status != null &&
              status != ConnectionStatus.connected &&
              status != ConnectionStatus.checking;
        })
        .map((profile) {
          return ScopedErrorViewModel(
            id: profile.id,
            connectionId: profile.id,
            title: profile.name,
            message: _connectionDetails[profile.id] ?? '连接不可用。',
          );
        })
        .toList(growable: false);
  }

  Future<void> initialize() async {
    try {
      final profiles = await _store.loadProfiles();
      if (_disposed) return;
      _profiles = profiles.toList();
      for (final profile in _profiles) {
        await _prepareClient(profile);
        if (_disposed) return;
      }
      await Future.wait(_profiles.map(_autoLogin));
      if (_disposed) return;
      await refreshAll(showSpinner: false);
    } on Object catch (error) {
      _showNotice(_friendlyError(error), isError: true);
    } finally {
      _initializing = false;
      _scheduleRefresh();
      _notify();
    }
  }

  void setSection(AppSection value) {
    if (_section == value) return;
    _section = value;
    _stopMonitoringRequests();
    _notify();
    if (value == AppSection.nodes) {
      unawaited(refreshNodeMonitoring());
    }
  }

  void setResourceFilter(ResourceFilterViewModel value) {
    _resourceFilter = value;
    _notify();
  }

  void setNodeFilter(NodeFilterViewModel value) {
    _nodeFilter = value;
    _notify();
  }

  void selectResource(ResourceViewModel? value) {
    _selectedResourceId = value?.id;
    _notify();
  }

  void selectNode(NodeViewModel? value) {
    if (_selectedNodeId != value?.id) _stopMonitoringRequests();
    _selectedNodeId = value?.id;
    _notify();
    unawaited(refreshNodeMonitoring());
  }

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (value) {
      _scheduleRefresh();
      unawaited(refreshAll());
    } else {
      _refreshTimer?.cancel();
      _stopMonitoringRequests();
      _notify();
    }
  }

  Future<ConnectionFlowResult> beginConnection(
    ConnectionFormValue value, {
    String? connectionId,
    bool saveOnSuccess = true,
  }) async {
    try {
      final cancellation = cancelPendingConnection();
      final generation = _pendingGeneration;
      await cancellation;
      if (!_isCurrentAttempt(generation)) return _cancelledConnection;
      final existing = connectionId == null ? null : profileById(connectionId);
      final profile = ConnectionProfile(
        id: connectionId ?? _uuid.v4(),
        name: value.name.trim(),
        host: value.host,
        port: value.port,
        username: value.username.trim(),
        realm: value.realm.trim(),
        rememberPassword: value.rememberPassword,
      );
      final identityUnchanged =
          existing != null &&
          existing.authority == profile.authority &&
          existing.userId == profile.userId;
      var password = value.password;
      if (password.isEmpty && identityUnchanged) {
        password = await _store.readPassword(existing.id) ?? '';
        if (!_isCurrentAttempt(generation)) return _cancelledConnection;
      }
      if (password.isEmpty &&
          identityUnchanged &&
          _sessions[profile.id] != null) {
        if (!saveOnSuccess) {
          final session = await _freshSession(profile.id);
          if (!_isCurrentAttempt(generation)) return _cancelledConnection;
          final client = _clients[profile.id];
          if (session == null || client == null) {
            return const ConnectionFlowFailed('会话已过期，请输入密码重新登录。');
          }
          try {
            await client.fetchVersion(session);
            if (!_isCurrentAttempt(generation)) return _cancelledConnection;
            return const ConnectionFlowSucceeded(saved: false);
          } on Object catch (error) {
            return ConnectionFlowFailed(_friendlyError(error));
          }
        }
        if (profile.rememberPassword && !existing.rememberPassword) {
          return const ConnectionFlowFailed('要启用记住密码，请输入密码。');
        }
        if (saveOnSuccess) {
          final saved = await _persistConnection(
            profile,
            isCurrent: () => _isCurrentAttempt(generation),
          );
          if (!saved || !_isCurrentAttempt(generation)) {
            return _cancelledConnection;
          }
          _replaceProfile(profile);
          _connectionStatuses[profile.id] = ConnectionStatus.connected;
          _notify();
        }
        return ConnectionFlowSucceeded(saved: saveOnSuccess);
      }
      if (password.isEmpty) {
        return const ConnectionFlowFailed('请输入 PVE 账号密码。');
      }

      final pending = _PendingConnection(
        profile: profile,
        password: password,
        saveOnSuccess: saveOnSuccess,
        generation: generation,
      );
      _pendingConnection = pending;
      _pendingTotpChallenge = null;
      _approvedPendingPin = null;
      _pendingCertificateError = null;
      return _attemptPendingPasswordLogin(pending);
    } on Object catch (error) {
      return ConnectionFlowFailed(_friendlyError(error));
    }
  }

  Future<ConnectionFlowResult> approvePendingCertificate() async {
    final pending = _pendingConnection;
    final certificate = _pendingCertificateError;
    if (pending == null || certificate == null) {
      return const ConnectionFlowFailed('没有待确认的证书。');
    }
    _approvedPendingPin = certificate.actualFingerprint;
    final client = await _preparePendingClient(
      pending,
      pin: certificate.actualFingerprint,
    );
    if (client == null || !_isCurrentPending(pending, client: client)) {
      return _cancelledConnection;
    }
    return _attemptPendingPasswordLogin(pending);
  }

  Future<ConnectionFlowResult> submitPendingTotp(String code) async {
    final pending = _pendingConnection;
    final challenge = _pendingTotpChallenge;
    if (pending == null || challenge == null) {
      return const ConnectionFlowFailed('TOTP 验证已过期，请重新登录。');
    }
    try {
      final client =
          _pendingClient ??
          await _preparePendingClient(pending, pin: _approvedPendingPin);
      if (client == null || !_isCurrentPending(pending, client: client)) {
        return _cancelledConnection;
      }
      final session = await client.completeTotp(
        challenge: challenge,
        code: code,
      );
      return _completePendingConnection(
        session,
        expectedPending: pending,
        expectedClient: client,
      );
    } on PveAuthenticationException catch (error) {
      if (!_isCurrentPending(pending)) {
        return _cancelledConnection;
      }
      _pendingTotpChallenge = null;
      return ConnectionFlowFailed(_friendlyError(error));
    } on Object catch (error) {
      return ConnectionFlowFailed(_friendlyError(error));
    }
  }

  Future<void> cancelPendingConnection({bool notify = true}) async {
    _pendingGeneration += 1;
    _pendingClient?.close();
    _pendingClient = null;
    _clearPendingConnection();
    if (notify) _notify();
    await _connectionWrites;
  }

  Future<void> deleteConnection(String connectionId) async {
    await _store.deleteProfile(connectionId);
    _clients.remove(connectionId)?.close();
    _clientGenerations[connectionId] =
        (_clientGenerations[connectionId] ?? 0) + 1;
    _sessions.remove(connectionId);
    _clearConnectionMonitoring(connectionId);
    _clearConnectionOperations(connectionId);
    _resources.remove(connectionId);
    _nodes.remove(connectionId);
    _lastUpdatedAt.remove(connectionId);
    _permissions.remove(connectionId);
    _connectionStatuses.remove(connectionId);
    _connectionDetails.remove(connectionId);
    _certificatePins.remove(connectionId);
    _certificateErrors.remove(connectionId);
    _profiles.removeWhere((profile) => profile.id == connectionId);
    if (_resourceFilter.connectionId == connectionId) {
      _resourceFilter = _resourceFilter.copyWith(clearConnection: true);
    }
    if (_nodeFilter.connectionId == connectionId) {
      _nodeFilter = _nodeFilter.copyWith(clearConnection: true);
    }
    _showNotice('连接已删除。');
    _notify();
  }

  Future<void> refreshAll({bool showSpinner = true}) async {
    if (_disposed || _refreshing || _profiles.isEmpty) return;
    _refreshing = true;
    if (showSpinner) _notify();
    await Future.wait(
      _profiles
          .where((profile) => _sessions.containsKey(profile.id))
          .map(_refreshConnection),
    );
    _refreshing = false;
    _ensureSelections();
    _notify();
    await refreshNodeMonitoring(forceHistory: showSpinner);
  }

  Future<void> runResourceAction(
    ResourceViewModel viewModel,
    ResourcePowerAction action,
  ) async {
    if (_resourceActions.containsKey(viewModel.id)) return;
    var resource = _findResource(viewModel.id);
    if (resource == null || !_canOperateConnection(resource.connectionId)) {
      return;
    }
    final profile = profileById(resource.connectionId);
    final client = _clients[resource.connectionId];
    final generation = _clientGenerations[resource.connectionId] ?? 0;
    if (profile == null || client == null) return;
    final operationToken = Object();
    _operationTokens[viewModel.id] = operationToken;
    _resourceActions[viewModel.id] = action;
    _operationMessages[viewModel.id] = '正在检查资源状态和权限…';
    _notify();
    var submitted = false;
    try {
      final session = await _freshSession(resource.connectionId);
      if (session == null || !_isActiveClient(profile, client, generation)) {
        throw const PveAuthenticationException('会话已过期，请重新登录。');
      }
      final currentResources = await client.fetchResources(session);
      final permissions = await client.fetchPermissions(session);
      if (!_isActiveClient(profile, client, generation)) return;
      resource = _firstWhereOrNull(
        currentResources,
        (item) => item.stableId == viewModel.id,
      );
      _resources[profile.id] = currentResources;
      _permissions[profile.id] = permissions;
      if (resource == null || resource.isTemplate || resource.lock != null) {
        throw const PveProtocolException('资源不可用或已锁定，已取消电源操作。');
      }
      if (!permissions.canPowerResource(resource.vmId)) {
        throw const PvePermissionException('当前账号没有资源电源管理权限。');
      }
      if ((action == ResourcePowerAction.start &&
              resource.status != PveResourceStatus.stopped) ||
          (action != ResourcePowerAction.start && !resource.isRunning)) {
        throw const PveProtocolException('资源状态已变化，已取消电源操作。');
      }
      _operationMessages[viewModel.id] = '操作已提交，正在等待 PVE 任务…';
      submitted = true;
      _notify();
      final task = await client.powerResource(
        session,
        resource,
        switch (action) {
          ResourcePowerAction.start => PveResourceAction.start,
          ResourcePowerAction.shutdown => PveResourceAction.shutdown,
          ResourcePowerAction.reboot => PveResourceAction.reboot,
        },
      );
      await client.waitForTask(session, task);
      if (!_isActiveClient(profile, client, generation)) return;
      _operationMessages[viewModel.id] = '操作已完成。';
      if (_isActiveClient(profile, client, generation)) {
        await _refreshConnection(profile);
      }
    } on Object catch (error) {
      if (!_isActiveClient(profile, client, generation)) return;
      _operationMessages[viewModel.id] =
          '${submitted ? '操作结果不确定' : '操作已取消'}：${_friendlyError(error)}';
      _showNotice(_operationMessages[viewModel.id]!, isError: true);
      if (_isActiveClient(profile, client, generation)) {
        await _refreshConnection(profile);
      }
    } finally {
      if (identical(_operationTokens[viewModel.id], operationToken)) {
        _operationTokens.remove(viewModel.id);
        _resourceActions.remove(viewModel.id);
        _notify();
      }
    }
  }

  Future<void> runNodeAction(
    NodeViewModel viewModel,
    NodePowerAction action,
  ) async {
    if (_nodeActions.containsKey(viewModel.id)) return;
    var node = _findNode(viewModel.id);
    if (node == null || !_canOperateConnection(node.connectionId)) return;
    final profile = profileById(node.connectionId);
    final client = _clients[node.connectionId];
    final generation = _clientGenerations[node.connectionId] ?? 0;
    if (profile == null || client == null) return;
    final operationToken = Object();
    _operationTokens[viewModel.id] = operationToken;
    _nodeActions[viewModel.id] = action;
    _notify();
    var submitted = false;
    var observing = false;
    try {
      final session = await _freshSession(node.connectionId);
      if (session == null || !_isActiveClient(profile, client, generation)) {
        throw const PveAuthenticationException('会话已过期，请重新登录。');
      }
      final currentNodes = await client.fetchNodes(session);
      final permissions = await client.fetchPermissions(session);
      if (!_isActiveClient(profile, client, generation)) {
        return;
      }
      node = _firstWhereOrNull(currentNodes, (item) => item.name == node!.name);
      if (node == null || !node.isOnline) {
        throw const PveProtocolException('节点当前不在线，已取消电源操作。');
      }
      _nodes[profile.id] = currentNodes;
      _permissions[profile.id] = permissions;
      if (!permissions.canPowerNode(node.name)) {
        throw const PvePermissionException('当前账号没有节点电源管理权限。');
      }
      submitted = true;
      await client.powerNode(
        session,
        node,
        action == NodePowerAction.shutdown
            ? PveNodeAction.shutdown
            : PveNodeAction.reboot,
      );
      if (!_isActiveClient(profile, client, generation)) return;
      _operationMessages[viewModel.id] = action == NodePowerAction.shutdown
          ? '关机命令已发送，等待节点离线。'
          : '重启命令已发送，等待节点重新上线。';
      _showNotice(_operationMessages[viewModel.id]!);
      _notify();
      observing = true;
      unawaited(
        _observeNodeTransition(
          profile,
          client,
          generation,
          operationToken,
          session,
          node,
          action,
        ),
      );
      return;
    } on Object catch (error) {
      if (!_isActiveClient(profile, client, generation)) return;
      _operationMessages[viewModel.id] =
          '${submitted ? '命令结果不确定' : '命令已取消'}：${_friendlyError(error)}';
      _showNotice(_operationMessages[viewModel.id]!, isError: true);
    } finally {
      if (!observing &&
          identical(_operationTokens[viewModel.id], operationToken)) {
        _operationTokens.remove(viewModel.id);
        _nodeActions.remove(viewModel.id);
        _notify();
      }
    }
  }

  Future<ConsoleLaunch?> consoleLaunchFor(ResourceViewModel viewModel) async {
    var resource = _findResource(viewModel.id);
    if (resource == null || !_canOperateConnection(resource.connectionId)) {
      return null;
    }
    final profile = profileById(resource.connectionId);
    final client = _clients[resource.connectionId];
    final generation = _clientGenerations[resource.connectionId] ?? 0;
    if (profile == null || client == null) return null;
    try {
      final session = await _freshSession(resource.connectionId);
      if (session == null || !_isActiveClient(profile, client, generation)) {
        throw const PveAuthenticationException('会话已过期，请重新登录。');
      }
      final currentResources = await client.fetchResources(session);
      final permissions = await client.fetchPermissions(session);
      if (!_isActiveClient(profile, client, generation)) return null;
      _resources[profile.id] = currentResources;
      _permissions[profile.id] = permissions;
      _notify();
      resource = _firstWhereOrNull(
        currentResources,
        (item) => item.stableId == viewModel.id,
      );
      if (resource == null ||
          !resource.isRunning ||
          resource.isTemplate ||
          resource.lock != null) {
        throw const PveProtocolException('资源当前无法打开控制台，请刷新后重试。');
      }
      if (!permissions.canOpenConsole(resource.vmId)) {
        throw const PvePermissionException('当前账号没有控制台权限。');
      }
      return ConsoleLaunch(
        title: resource.displayName,
        origin: profile.origin.toString(),
        ticket: session.ticket,
        consoleType: resource.type.name,
        node: resource.node,
        vmid: resource.vmId,
        pinnedSha256: _certificatePins[resource.connectionId],
      );
    } on Object catch (error) {
      _showNotice(_friendlyError(error), isError: true);
      return null;
    }
  }

  bool _canOperateConnection(String connectionId) =>
      _sessions.containsKey(connectionId) &&
      _connectionStatuses[connectionId] == ConnectionStatus.connected;

  ConnectionProfile? profileById(String id) =>
      _firstWhereOrNull(_profiles, (profile) => profile.id == id);

  ConnectionFormValue formValueFor(ConnectionProfile profile) {
    return ConnectionFormValue(
      name: profile.name,
      host: profile.host,
      port: profile.port,
      username: profile.username,
      realm: profile.realm,
      password: '',
      rememberPassword: profile.rememberPassword,
    );
  }

  Future<ConnectionFlowResult> _attemptPendingPasswordLogin(
    _PendingConnection pending,
  ) async {
    if (!_isCurrentPending(pending)) return _cancelledConnection;
    try {
      final client =
          _pendingClient ??
          await _preparePendingClient(pending, pin: _approvedPendingPin);
      if (client == null || !_isCurrentPending(pending, client: client)) {
        return _cancelledConnection;
      }
      final session = await client.login(password: pending.password);
      return _completePendingConnection(
        session,
        expectedPending: pending,
        expectedClient: client,
      );
    } on PveTotpRequiredException catch (error) {
      if (!_isCurrentPending(pending)) {
        return _cancelledConnection;
      }
      _pendingTotpChallenge = error.challenge;
      return ConnectionFlowNeedsTotp(availableMethods: error.availableMethods);
    } on PveCertificateException catch (error) {
      if (!_isCurrentPending(pending)) {
        return _cancelledConnection;
      }
      _pendingCertificateError = error;
      return ConnectionFlowNeedsCertificate(
        prompt: CertificatePromptViewModel(
          endpoint: Uri(
            scheme: 'https',
            host: error.host,
            port: error.port,
          ).toString(),
          sha256Fingerprint: error.actualFingerprint,
          previousFingerprint: error is PveCertificateMismatchException
              ? error.expectedFingerprint
              : null,
          isChanged: error is PveCertificateMismatchException,
        ),
      );
    } on Object catch (error) {
      return ConnectionFlowFailed(_friendlyError(error));
    }
  }

  Future<ConnectionFlowResult> _completePendingConnection(
    PveSession session, {
    required _PendingConnection expectedPending,
    required PveApiClient expectedClient,
  }) async {
    final pending = expectedPending;
    if (!_isCurrentPending(pending, client: expectedClient)) {
      return _cancelledConnection;
    }
    final profile = pending.profile;
    if (pending.saveOnSuccess) {
      final pin = _pendingClientPin;
      final approvedPin = _approvedPendingPin;
      final previous = profileById(profile.id);
      final identityChanged =
          previous != null &&
          (previous.authority != profile.authority ||
              previous.userId != profile.userId);
      final saved = await _persistConnection(
        profile,
        password: pending.password,
        approvedPin: approvedPin,
        isCurrent: () => _isCurrentPending(pending, client: expectedClient),
      );
      if (!saved || !_isCurrentPending(pending, client: expectedClient)) {
        return _cancelledConnection;
      }
      _replaceProfile(profile);
      if (identityChanged) {
        _clearConnectionOperations(profile.id);
        _lastUpdatedAt.remove(profile.id);
        _sessions.remove(profile.id);
        _resources.remove(profile.id);
        _nodes.remove(profile.id);
        _permissions.remove(profile.id);
      }
      _installActiveClient(profile, expectedClient, pin: pin);
      _pendingClient = null;
      _sessions[profile.id] = session;
      _connectionStatuses[profile.id] = ConnectionStatus.connected;
      _connectionDetails[profile.id] = '已连接';
      _certificateErrors.remove(profile.id);
      _clearPendingConnection();
      await _refreshConnection(profile);
      _showNotice('连接已保存并验证。');
      _notify();
      return const ConnectionFlowSucceeded(saved: true);
    }

    _pendingClient?.close();
    _pendingClient = null;
    _clearPendingConnection();
    return const ConnectionFlowSucceeded(saved: false);
  }

  Future<PveApiClient?> _prepareClient(
    ConnectionProfile profile, {
    String? pin,
  }) async {
    final savedPin = pin ?? await _store.readCertificatePin(profile);
    if (_disposed) return null;
    final client = _clientFactory(profile, savedPin);
    _installActiveClient(profile, client, pin: savedPin);
    return client;
  }

  Future<PveApiClient?> _preparePendingClient(
    _PendingConnection pending, {
    String? pin,
  }) async {
    if (!_isCurrentPending(pending)) return null;
    final profile = pending.profile;
    final savedPin = pin ?? await _store.readCertificatePin(profile);
    if (!_isCurrentPending(pending)) return null;
    _pendingClient?.close();
    final client = _clientFactory(profile, savedPin);
    _pendingClient = client;
    _pendingClientPin = savedPin;
    return client;
  }

  static const _cancelledConnection = ConnectionFlowFailed('登录流程已取消。');

  bool _isCurrentAttempt(int generation) =>
      !_disposed && generation == _pendingGeneration;

  bool _isCurrentPending(_PendingConnection pending, {PveApiClient? client}) =>
      _isCurrentAttempt(pending.generation) &&
      identical(_pendingConnection, pending) &&
      (client == null || identical(_pendingClient, client));

  Future<bool> _persistConnection(
    ConnectionProfile profile, {
    String? password,
    String? approvedPin,
    required bool Function() isCurrent,
  }) {
    final result = _connectionWrites.then((_) async {
      if (!isCurrent()) return false;
      final previous = profileById(profile.id);
      final previousPassword = previous?.rememberPassword == true
          ? await _store.readPassword(profile.id)
          : null;
      if (!isCurrent()) return false;
      final previousPin = previous == null
          ? null
          : await _store.readCertificatePin(previous);
      if (!isCurrent()) return false;
      var writesStarted = false;
      var saved = false;
      try {
        writesStarted = true;
        await _store.saveProfile(profile);
        if (!isCurrent()) return false;
        if (password != null && profile.rememberPassword) {
          await _store.writePassword(profile, password);
          if (!isCurrent()) return false;
        }
        if (approvedPin != null) {
          await _store.writeCertificatePin(profile, approvedPin);
          if (!isCurrent()) return false;
        }
        saved = true;
        return true;
      } finally {
        if (writesStarted && !saved) {
          if (previous == null) {
            await _store.deleteProfile(profile.id);
          } else {
            await _store.saveProfile(previous);
            if (previousPassword == null) {
              await _store.deletePassword(previous.id);
            } else {
              await _store.writePassword(previous, previousPassword);
            }
            if (previousPin == null) {
              await _store.deleteCertificatePin(previous.id);
            } else {
              await _store.writeCertificatePin(previous, previousPin);
            }
          }
        }
      }
    });
    _connectionWrites = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  void _installActiveClient(
    ConnectionProfile profile,
    PveApiClient client, {
    required String? pin,
  }) {
    _clearConnectionMonitoring(profile.id);
    _clients.remove(profile.id)?.close();
    _clientGenerations[profile.id] = (_clientGenerations[profile.id] ?? 0) + 1;
    _clients[profile.id] = client;
    _certificatePins[profile.id] = pin;
  }

  Future<void> _autoLogin(ConnectionProfile profile) async {
    if (_disposed) return;
    _connectionStatuses[profile.id] = ConnectionStatus.authenticationRequired;
    if (!profile.rememberPassword) {
      _connectionDetails[profile.id] = '需要登录';
      return;
    }
    final password = await _store.readPassword(profile.id);
    if (_disposed) return;
    if (password == null || password.isEmpty) {
      _connectionDetails[profile.id] = '未找到已保存的密码';
      return;
    }
    _connectionStatuses[profile.id] = ConnectionStatus.checking;
    final client = _clients[profile.id];
    final generation = _clientGenerations[profile.id] ?? 0;
    if (client == null) return;
    try {
      final session = await client.login(password: password);
      if (!_isActiveClient(profile, client, generation)) return;
      _sessions[profile.id] = session;
      _connectionStatuses[profile.id] = ConnectionStatus.connected;
      _connectionDetails[profile.id] = '已连接';
    } on PveTotpRequiredException {
      if (!_isActiveClient(profile, client, generation)) return;
      _connectionStatuses[profile.id] = ConnectionStatus.authenticationRequired;
      _connectionDetails[profile.id] = '需要 TOTP 验证';
    } on PveCertificateException catch (error) {
      if (!_isActiveClient(profile, client, generation)) return;
      _certificateErrors[profile.id] = error;
      _connectionStatuses[profile.id] = ConnectionStatus.certificateRequired;
      _connectionDetails[profile.id] = _friendlyError(error);
    } on Object catch (error) {
      if (!_isActiveClient(profile, client, generation)) return;
      _connectionStatuses[profile.id] = _statusForError(error);
      _connectionDetails[profile.id] = _friendlyError(error);
    }
  }

  Future<void> _refreshConnection(ConnectionProfile profile) async {
    if (_connectionStatuses[profile.id] ==
        ConnectionStatus.certificateRequired) {
      return;
    }
    var session = _sessions[profile.id];
    final client = _clients[profile.id];
    final generation = _clientGenerations[profile.id] ?? 0;
    if (session == null || client == null) return;
    try {
      if (session.shouldRenew(_now())) {
        session = await client.renewSession(session);
        if (!_isActiveClient(profile, client, generation)) return;
        _sessions[profile.id] = session;
      }
      final values = await Future.wait<Object>(<Future<Object>>[
        client.fetchResources(session),
        client.fetchNodes(session),
        client.fetchPermissions(session),
      ]);
      if (!_isActiveClient(profile, client, generation)) return;
      _resources[profile.id] = values[0] as List<PveResource>;
      _nodes[profile.id] = values[1] as List<PveNode>;
      _permissions[profile.id] = values[2] as PvePermissions;
      _lastUpdatedAt[profile.id] = _now();
      _connectionStatuses[profile.id] = ConnectionStatus.connected;
      _connectionDetails[profile.id] = '已连接';
      _certificateErrors.remove(profile.id);
    } on PveAuthenticationException catch (error) {
      if (!_isActiveClient(profile, client, generation)) return;
      _sessions.remove(profile.id);
      _connectionStatuses[profile.id] = ConnectionStatus.authenticationRequired;
      _connectionDetails[profile.id] = _friendlyError(error);
    } on PveCertificateException catch (error) {
      if (!_isActiveClient(profile, client, generation)) return;
      _certificateErrors[profile.id] = error;
      _connectionStatuses[profile.id] = ConnectionStatus.certificateRequired;
      _connectionDetails[profile.id] = _friendlyError(error);
    } on Object catch (error) {
      if (!_isActiveClient(profile, client, generation)) return;
      _connectionStatuses[profile.id] = _statusForError(error);
      _connectionDetails[profile.id] = _friendlyError(error);
    }
  }

  Future<PveSession?> _freshSession(String connectionId) async {
    var session = _sessions[connectionId];
    final client = _clients[connectionId];
    final profile = profileById(connectionId);
    final generation = _clientGenerations[connectionId] ?? 0;
    if (session == null || client == null || profile == null) return null;
    if (!session.shouldRenew(_now())) return session;
    final previousSession = session;
    try {
      session = await client.renewSession(session);
      if (!_isActiveClient(profile, client, generation)) return null;
      _sessions[connectionId] = session;
      return session;
    } on Object catch (error) {
      if (!_isActiveClient(profile, client, generation)) return null;
      if ((error is! PveNetworkException && error is! PveTimeoutException) ||
          previousSession.isExpired(_now())) {
        _sessions.remove(connectionId);
      }
      if (error is PveCertificateException) {
        _certificateErrors[connectionId] = error;
      }
      _connectionStatuses[connectionId] = _statusForError(error);
      _connectionDetails[connectionId] = _friendlyError(error);
      _notify();
      return null;
    }
  }

  bool _isActiveClient(
    ConnectionProfile expectedProfile,
    PveApiClient expectedClient,
    int expectedGeneration,
  ) {
    final activeProfile = profileById(expectedProfile.id);
    return !_disposed &&
        identical(_clients[expectedProfile.id], expectedClient) &&
        (_clientGenerations[expectedProfile.id] ?? 0) == expectedGeneration &&
        activeProfile != null &&
        activeProfile.authority == expectedProfile.authority &&
        activeProfile.userId == expectedProfile.userId;
  }

  Future<void> _observeNodeTransition(
    ConnectionProfile profile,
    PveApiClient client,
    int generation,
    Object operationToken,
    PveSession session,
    PveNode node,
    NodePowerAction action,
  ) async {
    try {
      await client.waitForNodePowerTransition(
        session,
        node,
        action == NodePowerAction.shutdown
            ? PveNodeAction.shutdown
            : PveNodeAction.reboot,
      );
      if (!_isActiveClient(profile, client, generation)) return;
      _operationMessages[node.stableId] = action == NodePowerAction.shutdown
          ? '节点已离线。'
          : '节点已重新上线。';
    } on Object catch (error) {
      if (!_isActiveClient(profile, client, generation)) return;
      _operationMessages[node.stableId] = '无法自动确认节点状态：${_friendlyError(error)}';
    } finally {
      if (identical(_operationTokens[node.stableId], operationToken)) {
        _operationTokens.remove(node.stableId);
        _nodeActions.remove(node.stableId);
        if (_isActiveClient(profile, client, generation)) {
          await _refreshConnection(profile);
        }
        _notify();
      }
    }
  }

  PveResource? _findResource(String stableId) {
    for (final items in _resources.values) {
      final match = _firstWhereOrNull(
        items,
        (item) => item.stableId == stableId,
      );
      if (match != null) return match;
    }
    return null;
  }

  PveNode? _findNode(String stableId) {
    for (final items in _nodes.values) {
      final match = _firstWhereOrNull(
        items,
        (item) => item.stableId == stableId,
      );
      if (match != null) return match;
    }
    return null;
  }

  void _replaceProfile(ConnectionProfile profile) {
    final index = _profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) {
      _profiles.add(profile);
    } else {
      _profiles[index] = profile;
    }
  }

  void _ensureSelections() {
    final resources = resourceViewModels;
    if (_selectedResourceId != null &&
        !resources.any((item) => item.id == _selectedResourceId)) {
      _selectedResourceId = null;
    }
    final nodes = nodeViewModels;
    if (_selectedNodeId != null &&
        !nodes.any((item) => item.id == _selectedNodeId)) {
      _selectedNodeId = null;
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (_disposed || !_foreground) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_refreshing) unawaited(refreshAll(showSpinner: false));
    });
  }

  void _clearPendingConnection() {
    _pendingConnection = null;
    _pendingTotpChallenge = null;
    _approvedPendingPin = null;
    _pendingClientPin = null;
    _pendingCertificateError = null;
  }

  void _showNotice(String message, {bool isError = false}) {
    _notice = message;
    _noticeIsError = isError;
    _noticeSerial += 1;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static ConnectionStatus _statusForError(Object error) {
    return switch (error) {
      PveAuthenticationException() => ConnectionStatus.authenticationRequired,
      PveCertificateException() => ConnectionStatus.certificateRequired,
      PveNetworkException() ||
      PveTimeoutException() => ConnectionStatus.networkUnavailable,
      _ => ConnectionStatus.error,
    };
  }

  static String _friendlyError(Object error) {
    return switch (error) {
      PveUntrustedCertificateException(:final actualFingerprint) =>
        '证书不受系统信任，指纹：$actualFingerprint',
      PveCertificateMismatchException(
        :final expectedFingerprint,
        :final actualFingerprint,
      ) =>
        '证书指纹已改变。已固定：$expectedFingerprint；收到：$actualFingerprint',
      PveAuthenticationException() => '认证失败，请检查账号、密码、认证域和系统时间。',
      PvePermissionException() => '当前 PVE 账号没有执行此操作的权限。',
      PveTimeoutException(:final operationMayHaveSucceeded) =>
        operationMayHaveSucceeded ? '请求超时，操作可能已到达 PVE，已禁止自动重试。' : '连接 PVE 超时。',
      PveNetworkException(:final operationMayHaveSucceeded) =>
        operationMayHaveSucceeded
            ? '网络中断，操作可能已到达 PVE，已禁止自动重试。'
            : '无法连接 PVE，请检查局域网或 VPN。',
      PveUnsupportedSecondFactorException() =>
        '该账号需要当前客户端不支持的 WebAuthn/U2F 验证方式。',
      PveException(:final message) => message,
      ArgumentError(:final message) => message?.toString() ?? '输入无效。',
      FormatException(:final message) => message,
      _ => '操作失败，请稍后重试。',
    };
  }

  static ResourceStatus _resourceStatus(PveResourceStatus value) {
    return switch (value) {
      PveResourceStatus.running => ResourceStatus.running,
      PveResourceStatus.stopped => ResourceStatus.stopped,
      PveResourceStatus.paused ||
      PveResourceStatus.suspended => ResourceStatus.paused,
      PveResourceStatus.unknown => ResourceStatus.unknown,
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _pendingClient?.close();
    for (final client in _clients.values) {
      client.close();
    }
    super.dispose();
  }
}

class _PendingConnection {
  const _PendingConnection({
    required this.profile,
    required this.password,
    required this.saveOnSuccess,
    required this.generation,
  });

  final ConnectionProfile profile;
  final String password;
  final bool saveOnSuccess;
  final int generation;
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
