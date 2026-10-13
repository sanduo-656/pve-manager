import 'package:flutter/material.dart';

import '../view_models.dart';
import 'inventory_widgets.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
    this.backgroundColor,
    this.dotColor,
  });
  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;
  final Color? backgroundColor;
  final Color? dotColor;
  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor ?? color,
          ),
        ),
        SizedBox(width: compact ? 4 : 5),
        Text(
          label,
          style: inventoryText(
            11,
            color: color,
            weight: compact ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ],
    );
    if (compact) return content;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: content,
    );
  }
}

class ResourceStatusBadge extends StatelessWidget {
  const ResourceStatusBadge(this.status, {super.key, this.compact = false});
  final ResourceStatus status;
  final bool compact;
  @override
  Widget build(BuildContext context) => switch (status) {
    ResourceStatus.running => StatusBadge(
      label: '运行中',
      color: const Color(0xFF168664),
      dotColor: const Color(0xFF15936A),
      backgroundColor: const Color(0xFFE4F5ED),
      compact: compact,
    ),
    ResourceStatus.stopped => StatusBadge(
      label: '已关机',
      color: const Color(0xFF6F7C92),
      dotColor: const Color(0xFF9AA3B4),
      backgroundColor: const Color(0xFFEDF0F6),
      compact: compact,
    ),
    ResourceStatus.paused => StatusBadge(
      label: '已暂停',
      color: const Color(0xFFB54708),
      backgroundColor: const Color(0xFFFFF4E5),
      compact: compact,
    ),
    ResourceStatus.unknown => StatusBadge(
      label: '未知',
      color: const Color(0xFF8D98AD),
      backgroundColor: const Color(0xFFEDF0F6),
      compact: compact,
    ),
  };
}

class NodeStatusBadge extends StatelessWidget {
  const NodeStatusBadge(this.status, {super.key, this.compact = false});
  final NodeStatus status;
  final bool compact;
  @override
  Widget build(BuildContext context) => switch (status) {
    NodeStatus.online => StatusBadge(
      label: '在线',
      color: const Color(0xFF168664),
      dotColor: const Color(0xFF15936A),
      backgroundColor: const Color(0xFFE4F5ED),
      compact: compact,
    ),
    NodeStatus.offline => StatusBadge(
      label: '离线',
      color: const Color(0xFFB42318),
      compact: compact,
    ),
    NodeStatus.unknown => StatusBadge(
      label: '未知',
      color: const Color(0xFF8D98AD),
      backgroundColor: const Color(0xFFEDF0F6),
      compact: compact,
    ),
  };
}

class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge(this.status, {super.key});
  final ConnectionStatus status;
  @override
  Widget build(BuildContext context) => switch (status) {
    ConnectionStatus.connected => const StatusBadge(
      label: '已连接',
      color: Color(0xFF168664),
      backgroundColor: Color(0xFFE4F5ED),
    ),
    ConnectionStatus.checking => const StatusBadge(
      label: '检测中',
      color: Color(0xFF3448C8),
    ),
    ConnectionStatus.authenticationRequired => const StatusBadge(
      label: '需登录',
      color: Color(0xFFB54708),
    ),
    ConnectionStatus.networkUnavailable => const StatusBadge(
      label: '网络不可达',
      color: Color(0xFFB42318),
    ),
    ConnectionStatus.certificateRequired => const StatusBadge(
      label: '证书待确认',
      color: Color(0xFFB54708),
    ),
    ConnectionStatus.error => const StatusBadge(
      label: '异常',
      color: Color(0xFFB42318),
    ),
    ConnectionStatus.unknown => const StatusBadge(
      label: '未检测',
      color: Color(0xFF8D98AD),
    ),
  };
}

class CertificateStatusBadge extends StatelessWidget {
  const CertificateStatusBadge(this.status, {super.key});
  final CertificateStatus status;
  @override
  Widget build(BuildContext context) => switch (status) {
    CertificateStatus.systemTrusted => const StatusBadge(
      label: '系统信任',
      color: Color(0xFF168664),
      backgroundColor: Color(0xFFE4F5ED),
    ),
    CertificateStatus.pinned => const StatusBadge(
      label: '指纹已固定',
      color: Color(0xFF3448C8),
    ),
    CertificateStatus.untrusted => const StatusBadge(
      label: '未信任',
      color: Color(0xFFB54708),
    ),
    CertificateStatus.changed => const StatusBadge(
      label: '证书已变化',
      color: Color(0xFFB42318),
    ),
    CertificateStatus.unknown => const StatusBadge(
      label: '未检测',
      color: Color(0xFF8D98AD),
    ),
  };
}
