import 'package:flutter/material.dart';

import '../view_models.dart';
import '../widgets/feedback_views.dart';
import '../widgets/status_badge.dart';
import '../widgets/inventory_widgets.dart';
import '../widgets/pve_icon.dart';

class ResourceDetailPane extends StatelessWidget {
  const ResourceDetailPane({
    super.key,
    required this.resource,
    this.onBack,
    this.onStart,
    this.onShutdown,
    this.onReboot,
    this.onOpenConsole,
  });

  final ResourceViewModel? resource;
  final VoidCallback? onBack;
  final ResourceAction? onStart;
  final ResourceAction? onShutdown;
  final ResourceAction? onReboot;
  final ResourceAction? onOpenConsole;

  @override
  Widget build(BuildContext context) {
    final current = resource;
    if (current == null) {
      return const PaneStateView(
        state: PaneStateViewModel.empty(
          title: '选择资源',
          message: '从列表中选择一台虚拟机或容器查看详情。',
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
                title: '资源详情',
                backLabel: '返回资源列表',
                onBack: onBack,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  InventoryIcon(
                    icon: current.kind == ResourceKind.qemu
                        ? PveIconName.monitor
                        : PveIconName.box,
                    secondary: current.kind == ResourceKind.lxc,
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
                          '${current.kind == ResourceKind.qemu ? '虚拟机' : '容器'} ${current.guestId} · ${current.nodeName}',
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
                  ResourceStatusBadge(current.status),
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
              _ResourceMetrics(resource: current),
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
                    InventoryMetadataRow(label: '节点', value: current.nodeName),
                    const SizedBox(height: 15),
                    InventoryMetadataRow(
                      label: '资源 ID',
                      value: current.guestId,
                    ),
                    const SizedBox(height: 15),
                    InventoryMetadataRow(
                      label: '类型',
                      value: current.kind == ResourceKind.qemu
                          ? 'QEMU 虚拟机'
                          : 'LXC 容器',
                    ),
                    const SizedBox(height: 15),
                    InventoryMetadataRow(
                      label: '所属连接',
                      value: current.connectionName,
                    ),
                  ],
                ),
              ),
              if (current.operationMessage case final message?) ...[
                const SizedBox(height: 16),
                OperationNotice(message: message),
              ],
              const SizedBox(height: 22),
              _ActionBar(
                resource: current,
                onStart: onStart,
                onShutdown: onShutdown,
                onReboot: onReboot,
                onOpenConsole: onOpenConsole,
              ),
              const SizedBox(height: 12),
              Text(
                '关机与重启需要确认，并自动跟踪执行结果。',
                textAlign: TextAlign.center,
                style: inventoryText(11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceMetrics extends StatelessWidget {
  const _ResourceMetrics({required this.resource});
  final ResourceViewModel resource;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: InventoryMetric(
          label: 'CPU',
          value: normalizedProgress(resource.cpuUsage) == null
              ? '—'
              : '${(normalizedProgress(resource.cpuUsage)! * 100).toStringAsFixed(1)}%',
          description: '实时使用率',
          progress: resource.cpuUsage,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: InventoryMetric(
          label: '内存',
          value:
              resource.memoryUsedBytes == null || resource.memoryUsedBytes! < 0
              ? '—'
              : formatBytes(resource.memoryUsedBytes!),
          description:
              resource.memoryTotalBytes == null ||
                  resource.memoryTotalBytes! <= 0
              ? '总容量未知'
              : '共 ${formatMemoryCapacity(resource.memoryTotalBytes!)}',
          progress: memoryFraction(
            resource.memoryUsedBytes,
            resource.memoryTotalBytes,
          ),
          secondary: true,
        ),
      ),
    ],
  );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.resource,
    required this.onStart,
    required this.onShutdown,
    required this.onReboot,
    required this.onOpenConsole,
  });
  final ResourceViewModel resource;
  final ResourceAction? onStart;
  final ResourceAction? onShutdown;
  final ResourceAction? onReboot;
  final ResourceAction? onOpenConsole;
  @override
  Widget build(BuildContext context) {
    final canPower = resource.capabilities.canPower && !resource.isBusy;
    final canStop = canPower && resource.isRunning;
    final canConsole =
        resource.capabilities.canConsole &&
        resource.isRunning &&
        !resource.isBusy;
    final start = resource.status == ResourceStatus.stopped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: inventoryPrimaryButtonStyle(),
          onPressed: start
              ? (canPower && onStart != null ? () => onStart!(resource) : null)
              : (canConsole && onOpenConsole != null
                    ? () => onOpenConsole!(resource)
                    : null),
          icon: resource.activeAction == ResourcePowerAction.start
              ? const _ButtonSpinner()
              : PveIcon(
                  start ? PveIconName.power : PveIconName.terminal,
                  size: 19,
                ),
          label: Text(
            start
                ? '开机'
                : resource.kind == ResourceKind.qemu
                ? '打开控制台'
                : '打开终端',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: inventorySecondaryButtonStyle(),
                onPressed: canStop && onShutdown != null
                    ? () => _confirmPowerAction(
                        context,
                        title: '关闭 ${resource.name}？',
                        message: '将向客户机发送正常关机请求。',
                        confirmLabel: '正常关机',
                        icon: PveIconName.power,
                        action: () => onShutdown!(resource),
                      )
                    : null,
                child: InventoryButtonContent(
                  icon: resource.activeAction == ResourcePowerAction.shutdown
                      ? const _ButtonSpinner()
                      : const PveIcon(PveIconName.power, size: 17),
                  label: '正常关机',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: inventorySecondaryButtonStyle(),
                onPressed: canStop && onReboot != null
                    ? () => _confirmPowerAction(
                        context,
                        title: '重启 ${resource.name}？',
                        message: '将向客户机发送正常重启请求。',
                        confirmLabel: '重启',
                        icon: PveIconName.rotateCw,
                        action: () => onReboot!(resource),
                      )
                    : null,
                child: InventoryButtonContent(
                  icon: resource.activeAction == ResourcePowerAction.reboot
                      ? const _ButtonSpinner()
                      : const PveIcon(PveIconName.rotateCw, size: 17),
                  label: '重启',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

Future<void> _confirmPowerAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required PveIconName icon,
  required UiAction action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: PveIcon(icon, size: 17),
          label: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (confirmed == true) await action();
}
