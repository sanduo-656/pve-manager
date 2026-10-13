import 'dart:async';

enum AppSection { resources, nodes, connections }

enum PaneStatus {
  ready,
  loading,
  empty,
  authenticationRequired,
  certificateRequired,
  error,
}

enum ResourceKind { qemu, lxc }

enum ResourceStatus { running, stopped, paused, unknown }

enum NodeStatus { online, offline, unknown }

enum ResourcePowerAction { start, shutdown, reboot }

enum NodePowerAction { shutdown, reboot }

enum ConnectionStatus {
  connected,
  checking,
  authenticationRequired,
  networkUnavailable,
  certificateRequired,
  error,
  unknown,
}

enum CertificateStatus { systemTrusted, pinned, untrusted, changed, unknown }

typedef UiAction = FutureOr<void> Function();
typedef ResourceAction = FutureOr<void> Function(ResourceViewModel resource);
typedef NodeAction = FutureOr<void> Function(NodeViewModel node);
typedef ConnectionAction =
    FutureOr<void> Function(ConnectionViewModel connection);
typedef ConnectionFormAction =
    FutureOr<void> Function(ConnectionFormValue value);
typedef TotpAction = FutureOr<void> Function(String code);

class PaneStateViewModel {
  const PaneStateViewModel({
    this.status = PaneStatus.ready,
    this.title,
    this.message,
    this.actionLabel,
  });

  const PaneStateViewModel.loading({String? message})
    : this(status: PaneStatus.loading, message: message);

  const PaneStateViewModel.empty({
    String? title,
    String? message,
    String? actionLabel,
  }) : this(
         status: PaneStatus.empty,
         title: title,
         message: message,
         actionLabel: actionLabel,
       );

  const PaneStateViewModel.authenticationRequired({String? message})
    : this(
        status: PaneStatus.authenticationRequired,
        title: '需要重新登录',
        message: message,
        actionLabel: '重新登录',
      );

  const PaneStateViewModel.certificateRequired({String? message})
    : this(
        status: PaneStatus.certificateRequired,
        title: '证书需要确认',
        message: message,
        actionLabel: '查看证书',
      );

  const PaneStateViewModel.error({String? title, String? message})
    : this(
        status: PaneStatus.error,
        title: title ?? '加载失败',
        message: message,
        actionLabel: '重试',
      );

  final PaneStatus status;
  final String? title;
  final String? message;
  final String? actionLabel;

  bool get showsContent => status == PaneStatus.ready;
}

class ScopedErrorViewModel {
  const ScopedErrorViewModel({
    required this.id,
    required this.title,
    required this.message,
    this.connectionId,
  });

  final String id;
  final String title;
  final String message;
  final String? connectionId;
}

class ResourceCapabilitiesViewModel {
  const ResourceCapabilitiesViewModel({
    this.canAudit = true,
    this.canPower = false,
    this.canConsole = false,
  });

  final bool canAudit;
  final bool canPower;
  final bool canConsole;
}

class ResourceViewModel {
  const ResourceViewModel({
    required this.id,
    required this.connectionId,
    required this.connectionName,
    required this.nodeName,
    required this.guestId,
    required this.name,
    required this.kind,
    required this.status,
    this.cpuUsage,
    this.memoryUsedBytes,
    this.memoryTotalBytes,
    this.capabilities = const ResourceCapabilitiesViewModel(),
    this.activeAction,
    this.operationMessage,
  });

  final String id;
  final String connectionId;
  final String connectionName;
  final String nodeName;
  final String guestId;
  final String name;
  final ResourceKind kind;
  final ResourceStatus status;
  final double? cpuUsage;
  final int? memoryUsedBytes;
  final int? memoryTotalBytes;
  final ResourceCapabilitiesViewModel capabilities;
  final ResourcePowerAction? activeAction;
  final String? operationMessage;

  bool get isRunning => status == ResourceStatus.running;
  bool get isBusy => activeAction != null;
}

class ConnectionOptionViewModel {
  const ConnectionOptionViewModel({required this.id, required this.name});

  final String id;
  final String name;
}

class ResourceFilterViewModel {
  const ResourceFilterViewModel({
    this.query = '',
    this.kind,
    this.status,
    this.connectionId,
  });

  final String query;
  final ResourceKind? kind;
  final ResourceStatus? status;
  final String? connectionId;

  ResourceFilterViewModel copyWith({
    String? query,
    ResourceKind? kind,
    bool clearKind = false,
    ResourceStatus? status,
    bool clearStatus = false,
    String? connectionId,
    bool clearConnection = false,
  }) {
    return ResourceFilterViewModel(
      query: query ?? this.query,
      kind: clearKind ? null : kind ?? this.kind,
      status: clearStatus ? null : status ?? this.status,
      connectionId: clearConnection ? null : connectionId ?? this.connectionId,
    );
  }
}

class NodeCapabilitiesViewModel {
  const NodeCapabilitiesViewModel({
    this.canAudit = true,
    this.canPower = false,
  });

  final bool canAudit;
  final bool canPower;
}

class NodeViewModel {
  const NodeViewModel({
    required this.id,
    required this.connectionId,
    required this.connectionName,
    required this.name,
    required this.status,
    this.cpuUsage,
    this.memoryUsedBytes,
    this.memoryTotalBytes,
    this.uptime,
    this.capabilities = const NodeCapabilitiesViewModel(),
    this.activeAction,
    this.operationMessage,
  });

  final String id;
  final String connectionId;
  final String connectionName;
  final String name;
  final NodeStatus status;
  final double? cpuUsage;
  final int? memoryUsedBytes;
  final int? memoryTotalBytes;
  final Duration? uptime;
  final NodeCapabilitiesViewModel capabilities;
  final NodePowerAction? activeAction;
  final String? operationMessage;

  bool get isOnline => status == NodeStatus.online;
  bool get isBusy => activeAction != null;
}

class NodeFilterViewModel {
  const NodeFilterViewModel({this.query = '', this.connectionId});

  final String query;
  final String? connectionId;

  NodeFilterViewModel copyWith({
    String? query,
    String? connectionId,
    bool clearConnection = false,
  }) {
    return NodeFilterViewModel(
      query: query ?? this.query,
      connectionId: clearConnection ? null : connectionId ?? this.connectionId,
    );
  }
}

class ConnectionViewModel {
  const ConnectionViewModel({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.realm,
    required this.status,
    required this.certificateStatus,
    this.rememberPassword = false,
    this.detail,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String realm;
  final ConnectionStatus status;
  final CertificateStatus certificateStatus;
  final bool rememberPassword;
  final String? detail;

  String get endpoint =>
      Uri(scheme: 'https', host: host, port: port).toString();
  String get account => username.contains('@') ? username : '$username@$realm';
}

class ConnectionFormValue {
  const ConnectionFormValue({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.realm,
    required this.password,
    required this.rememberPassword,
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final String realm;
  final String password;
  final bool rememberPassword;

  factory ConnectionFormValue.defaults() {
    return const ConnectionFormValue(
      name: '',
      host: '',
      port: 8006,
      username: '',
      realm: 'pam',
      password: '',
      rememberPassword: false,
    );
  }
}

class CertificatePromptViewModel {
  const CertificatePromptViewModel({
    required this.endpoint,
    required this.sha256Fingerprint,
    this.previousFingerprint,
    this.isChanged = false,
  });

  final String endpoint;
  final String sha256Fingerprint;
  final String? previousFingerprint;
  final bool isChanged;
}
