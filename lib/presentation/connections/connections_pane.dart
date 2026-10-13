import 'package:flutter/material.dart';

import '../view_models.dart';
import '../widgets/feedback_views.dart';
import '../widgets/status_badge.dart';

class ConnectionsPane extends StatelessWidget {
  const ConnectionsPane({
    super.key,
    required this.connections,
    required this.onAdd,
    this.state = const PaneStateViewModel(),
    this.partialErrors = const [],
    this.onStateAction,
    this.onRetryPartialErrors,
    this.onEdit,
    this.onDelete,
    this.onTest,
    this.onRelogin,
  });

  final List<ConnectionViewModel> connections;
  final UiAction onAdd;
  final PaneStateViewModel state;
  final List<ScopedErrorViewModel> partialErrors;
  final UiAction? onStateAction;
  final UiAction? onRetryPartialErrors;
  final ConnectionAction? onEdit;
  final ConnectionAction? onDelete;
  final ConnectionAction? onTest;
  final ConnectionAction? onRelogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = connections
        .where((item) => item.status == ConnectionStatus.connected)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连接', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 3),
                  Text(
                    connections.isEmpty
                        ? '管理你的 PVE 服务器'
                        : '${connections.length} 个服务器 · $connected 个已连接',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              final addButton = FilledButton.icon(
                onPressed: () => onAdd(),
                icon: const Icon(Icons.add),
                label: const Text('新增连接'),
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [heading, const SizedBox(height: 16), addButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  addButton,
                ],
              );
            },
          ),
        ),
        PartialErrorBanner(
          errors: partialErrors,
          onRetry: onRetryPartialErrors,
        ),
        Expanded(
          child: !state.showsContent
              ? PaneStateView(state: state, onAction: onStateAction)
              : connections.isEmpty
              ? PaneStateView(
                  state: const PaneStateViewModel(
                    status: PaneStatus.empty,
                    title: '还没有 PVE 连接',
                    message: '添加第一个服务器连接后即可查看和管理资源。',
                    actionLabel: '新增连接',
                  ),
                  onAction: onAdd,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: connections.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              itemBuilder: (context, index) => _ConnectionItem(
                                connection: connections[index],
                                onEdit: onEdit,
                                onDelete: onDelete,
                                onTest: onTest,
                                onRelogin: onRelogin,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

enum _ConnectionMenuAction { test, relogin, edit, delete }

class _ConnectionItem extends StatelessWidget {
  const _ConnectionItem({
    required this.connection,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
    required this.onRelogin,
  });

  final ConnectionViewModel connection;
  final ConnectionAction? onEdit;
  final ConnectionAction? onDelete;
  final ConnectionAction? onTest;
  final ConnectionAction? onRelogin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 4, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.dns_outlined,
                color: colors.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    connection.endpoint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    connection.account,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConnectionStatusBadge(connection.status),
                      if (connection.certificateStatus ==
                              CertificateStatus.untrusted ||
                          connection.certificateStatus ==
                              CertificateStatus.changed)
                        CertificateStatusBadge(connection.certificateStatus)
                      else
                        Tooltip(
                          message: switch (connection.certificateStatus) {
                            CertificateStatus.systemTrusted => '证书由系统信任',
                            CertificateStatus.pinned => '已固定服务器证书指纹',
                            _ => '证书尚未检查',
                          },
                          child: Icon(
                            connection.certificateStatus ==
                                    CertificateStatus.unknown
                                ? Icons.shield_outlined
                                : Icons.verified_user_outlined,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      if (connection.rememberPassword)
                        Tooltip(
                          message: '密码已加密保存在此设备',
                          child: Icon(
                            Icons.key_outlined,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (connection.detail case final detail?
                      when detail != '已连接' && detail.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            connection.status == ConnectionStatus.error ||
                                connection.status ==
                                    ConnectionStatus.networkUnavailable
                            ? colors.error
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<_ConnectionMenuAction>(
              enabled:
                  onEdit != null ||
                  onDelete != null ||
                  onTest != null ||
                  onRelogin != null,
              tooltip: '连接操作',
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case _ConnectionMenuAction.test:
                    onTest?.call(connection);
                  case _ConnectionMenuAction.relogin:
                    onRelogin?.call(connection);
                  case _ConnectionMenuAction.edit:
                    onEdit?.call(connection);
                  case _ConnectionMenuAction.delete:
                    _confirmDelete(context);
                }
              },
              itemBuilder: (context) => [
                if (onTest != null)
                  const PopupMenuItem(
                    value: _ConnectionMenuAction.test,
                    child: ListTile(
                      leading: Icon(Icons.network_check),
                      title: Text('测试连接'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onRelogin != null)
                  const PopupMenuItem(
                    value: _ConnectionMenuAction.relogin,
                    child: ListTile(
                      leading: Icon(Icons.login),
                      title: Text('重新登录'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onEdit != null)
                  const PopupMenuItem(
                    value: _ConnectionMenuAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('编辑'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: _ConnectionMenuAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: colors.error),
                      title: Text('删除', style: TextStyle(color: colors.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${connection.name}？'),
        content: const Text('本机保存的连接配置和密码将被移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete?.call(connection);
  }
}
