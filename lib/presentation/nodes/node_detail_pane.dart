import 'package:flutter/material.dart';

import '../../features/nodes/domain/pve_node_metrics.dart';
import 'node_monitoring_pane.dart';
import 'node_monitoring_state.dart';
import '../widgets/inventory_widgets.dart';
import '../widgets/pve_icon.dart';
import '../view_models.dart';
import '../widgets/feedback_views.dart';
import '../widgets/status_badge.dart';

class NodeDetailPane extends StatelessWidget {
  const NodeDetailPane({
    super.key,
    required this.node,
    this.onBack,
    this.onShutdown,
    this.onReboot,
    this.monitoring,
    this.onMonitoringTimeframeChanged,
    this.onRefreshMonitoring,
  });

  final NodeViewModel? node;
  final VoidCallback? onBack;
  final NodeAction? onShutdown;
  final NodeAction? onReboot;
  final NodeMonitoringState? monitoring;
  final ValueChanged<PveNodeTimeframe>? onMonitoringTimeframeChanged;
  final VoidCallback? onRefreshMonitoring;

  @override
  Widget build(BuildContext context) {
    final current = node;
    if (current == null) {
      return const PaneStateView(
        state: PaneStateViewModel.empty(
          title: '选择节点',
          message: '从列表中选择一个 PVE 宿主节点查看详情。',
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InventoryDetailHeading(
                title: '节点详情',
                backLabel: '返回节点列表',
                onBack: onBack,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const InventoryIcon(
                    icon: PveIconName.server,
                    size: 50,
                    detail: true,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: inventoryText(21, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Proxmox VE 宿主节点',
                          style: inventoryText(
                            12,
                            color: const Color(0xFF68758C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  NodeStatusBadge(current.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      current.connectionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: inventoryText(12, color: const Color(0xFF68758C)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (monitoring != null) ...[
                if (!current.capabilities.canAudit || !current.isOnline) ...[
                  _MonitoringAvailability(node: current),
                  const SizedBox(height: 12),
                ],
                NodeMonitoringPane(
                  state: monitoring!,
                  onTimeframeChanged:
                      current.capabilities.canAudit && current.isOnline
                      ? onMonitoringTimeframeChanged
                      : null,
                  onRefresh: current.capabilities.canAudit && current.isOnline
                      ? onRefreshMonitoring
                      : null,
                ),
              ] else
                _NodeMetrics(node: current),
              const SizedBox(height: 22),
              InventorySurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '基本信息',
                      style: inventoryText(
                        14,
                        color: const Color(0xFF263450),
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 15),
                    InventoryMetadataRow(label: '节点', value: current.name),
                    const SizedBox(height: 15),
                    InventoryMetadataRow(
                      label: '所属连接',
                      value: current.connectionName,
                    ),
                    const SizedBox(height: 15),
                    InventoryMetadataRow(
                      label: '运行时间',
                      value: _formatDuration(current.uptime),
                    ),
                  ],
                ),
              ),
              if (current.operationMessage case final message?) ...[
                const SizedBox(height: 16),
                OperationNotice(message: message),
              ],
              const SizedBox(height: 22),
              InventorySurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const PveIcon(
                          PveIconName.power,
                          size: 17,
                          color: Color(0xFFB42318),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '节点电源管理',
                          style: inventoryText(
                            14,
                            color: const Color(0xFF263450),
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('节点关机或重启会影响其上运行的全部虚拟机与容器。', style: inventoryText(11)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: inventorySecondaryButtonStyle(danger: true),
                            onPressed:
                                _canOperate(current) && onShutdown != null
                                ? () => showNodeNameConfirmation(
                                    context,
                                    node: current,
                                    action: NodePowerAction.shutdown,
                                    onConfirmed: () => onShutdown!(current),
                                  )
                                : null,
                            child: InventoryButtonContent(
                              icon:
                                  current.activeAction ==
                                      NodePowerAction.shutdown
                                  ? const _NodeActionSpinner()
                                  : const PveIcon(PveIconName.power, size: 17),
                              label: '关闭节点',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: inventorySecondaryButtonStyle(),
                            onPressed: _canOperate(current) && onReboot != null
                                ? () => showNodeNameConfirmation(
                                    context,
                                    node: current,
                                    action: NodePowerAction.reboot,
                                    onConfirmed: () => onReboot!(current),
                                  )
                                : null,
                            child: InventoryButtonContent(
                              icon:
                                  current.activeAction == NodePowerAction.reboot
                                  ? const _NodeActionSpinner()
                                  : const PveIcon(
                                      PveIconName.rotateCw,
                                      size: 17,
                                    ),
                              label: '重启节点',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canOperate(NodeViewModel node) =>
      node.isOnline && node.capabilities.canPower && !node.isBusy;
}

class _MonitoringAvailability extends StatelessWidget {
  const _MonitoringAvailability({required this.node});

  final NodeViewModel node;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        !node.capabilities.canAudit
            ? '当前账号没有节点监控权限，需要 Sys.Audit 权限。'
            : node.status == NodeStatus.offline
            ? '节点当前离线，监控暂停更新；已有数据仅供参考。'
            : '节点状态未知，监控暂停更新；已有数据仅供参考。',
        style: inventoryText(12, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _NodeMetrics extends StatelessWidget {
  const _NodeMetrics({required this.node});
  final NodeViewModel node;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: InventoryMetric(
          label: 'CPU',
          value: normalizedProgress(node.cpuUsage) == null
              ? '—'
              : '${(normalizedProgress(node.cpuUsage)! * 100).toStringAsFixed(1)}%',
          description: '实时使用率',
          progress: node.cpuUsage,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: InventoryMetric(
          label: '内存',
          value: node.memoryUsedBytes == null || node.memoryUsedBytes! < 0
              ? '—'
              : formatBytes(node.memoryUsedBytes!),
          description:
              node.memoryTotalBytes == null || node.memoryTotalBytes! <= 0
              ? '总容量未知'
              : '共 ${formatMemoryCapacity(node.memoryTotalBytes!)}',
          progress: memoryFraction(node.memoryUsedBytes, node.memoryTotalBytes),
          secondary: true,
        ),
      ),
    ],
  );
}

String _formatDuration(Duration? duration) {
  if (duration == null) return '—';
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  if (days > 0) return '$days 天 $hours 小时';
  final minutes = duration.inMinutes.remainder(60);
  return '$hours 小时 $minutes 分钟';
}

class _NodeActionSpinner extends StatelessWidget {
  const _NodeActionSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

Future<void> showNodeNameConfirmation(
  BuildContext context, {
  required NodeViewModel node,
  required NodePowerAction action,
  required UiAction onConfirmed,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        NodeNameConfirmationDialog(nodeName: node.name, action: action),
  );
  if (confirmed == true) await onConfirmed();
}

class NodeNameConfirmationDialog extends StatefulWidget {
  const NodeNameConfirmationDialog({
    super.key,
    required this.nodeName,
    required this.action,
  });

  final String nodeName;
  final NodePowerAction action;

  @override
  State<NodeNameConfirmationDialog> createState() =>
      _NodeNameConfirmationDialogState();
}

class _NodeNameConfirmationDialogState
    extends State<NodeNameConfirmationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isShutdown = widget.action == NodePowerAction.shutdown;
    final label = isShutdown ? '关闭节点' : '重启节点';
    final matches = _controller.text == widget.nodeName;
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: PveIcon(PveIconName.power, color: colors.error),
      title: Text('$label？'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('此操作会影响节点 ${widget.nodeName} 上运行的全部工作负载。'),
            const SizedBox(height: 16),
            Text('输入节点名 ${widget.nodeName} 以确认：'),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('node-name-confirmation-field'),
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: '节点名'),
              onSubmitted: matches ? (_) => Navigator.pop(context, true) : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const ValueKey('confirm-node-power-action'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          icon: PveIcon(
            isShutdown ? PveIconName.power : PveIconName.rotateCw,
            size: 17,
          ),
          label: Text(label),
        ),
      ],
    );
  }
}
