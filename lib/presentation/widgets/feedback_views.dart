import 'package:flutter/material.dart';

import '../view_models.dart';

class PaneStateView extends StatelessWidget {
  const PaneStateView({
    super.key,
    required this.state,
    this.onAction,
    this.compact = false,
  });

  final PaneStateViewModel state;
  final UiAction? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (state.status == PaneStatus.ready) return const SizedBox.shrink();

    final (icon, fallbackTitle) = switch (state.status) {
      PaneStatus.loading => (Icons.sync, '正在加载'),
      PaneStatus.empty => (Icons.inbox_outlined, '暂无数据'),
      PaneStatus.authenticationRequired => (Icons.lock_outline, '需要重新登录'),
      PaneStatus.certificateRequired => (Icons.gpp_maybe_outlined, '证书需要确认'),
      PaneStatus.error => (Icons.error_outline, '加载失败'),
      PaneStatus.ready => (Icons.info_outline, ''),
    };
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.status == PaneStatus.loading)
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Container(
                  width: compact ? 60 : 80,
                  height: compact ? 60 : 80,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 28 : 36,
                    color: colors.primary,
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                state.title ?? fallbackTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (state.message case final message?) ...[
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (onAction != null &&
                  state.status != PaneStatus.loading &&
                  state.actionLabel != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => onAction!(),
                  icon: Icon(switch (state.status) {
                    PaneStatus.empty => Icons.add,
                    PaneStatus.authenticationRequired => Icons.login,
                    PaneStatus.certificateRequired => Icons.policy_outlined,
                    _ => Icons.refresh,
                  }),
                  label: Text(state.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PartialErrorBanner extends StatelessWidget {
  const PartialErrorBanner({super.key, required this.errors, this.onRetry});

  final List<ScopedErrorViewModel> errors;
  final UiAction? onRetry;

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final first = errors.first;
    final remaining = errors.length - 1;

    return Material(
      color: colors.tertiaryContainer.withValues(alpha: 0.45),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFF79009), width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFB54708)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remaining > 0
                        ? '${first.title}，另有 $remaining 项异常'
                        : first.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    first.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              TextButton.icon(
                onPressed: () => onRetry!(),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
          ],
        ),
      ),
    );
  }
}

class OperationNotice extends StatelessWidget {
  const OperationNotice({
    super.key,
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: isError
                ? colors.onErrorContainer
                : colors.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? colors.onErrorContainer
                    : colors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
