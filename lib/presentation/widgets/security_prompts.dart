import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../view_models.dart';

class CertificateApprovalPane extends StatelessWidget {
  const CertificateApprovalPane({
    super.key,
    required this.certificate,
    required this.onApprove,
    required this.onReject,
  });

  final CertificatePromptViewModel certificate;
  final UiAction onApprove;
  final UiAction onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isChanged = certificate.isChanged;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isChanged ? Icons.gpp_bad_outlined : Icons.gpp_maybe_outlined,
                size: 48,
                color: isChanged ? colors.error : const Color(0xFFB54708),
              ),
              const SizedBox(height: 16),
              Text(
                isChanged ? '服务器证书已变化' : '确认服务器证书',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                certificate.endpoint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (certificate.previousFingerprint case final previous?) ...[
                _FingerprintBlock(label: '原 SHA-256 指纹', value: previous),
                const SizedBox(height: 12),
              ],
              _FingerprintBlock(
                label: isChanged ? '当前 SHA-256 指纹' : 'SHA-256 指纹',
                value: certificate.sha256Fingerprint,
              ),
              const SizedBox(height: 16),
              Text(
                isChanged ? '请先通过可信渠道核对新指纹。未确认前连接保持阻断。' : '请通过可信渠道核对指纹后再固定此证书。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isChanged ? colors.error : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  TextButton(
                    onPressed: () => onReject(),
                    child: const Text('取消'),
                  ),
                  FilledButton.icon(
                    style: isChanged
                        ? FilledButton.styleFrom(
                            backgroundColor: colors.error,
                            foregroundColor: colors.onError,
                          )
                        : null,
                    onPressed: () => onApprove(),
                    icon: const Icon(Icons.fingerprint),
                    label: Text(isChanged ? '确认并重新固定' : '确认并固定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FingerprintBlock extends StatelessWidget {
  const _FingerprintBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class TotpChallengeDialog extends StatefulWidget {
  const TotpChallengeDialog({
    super.key,
    required this.connectionName,
    required this.onSubmit,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String connectionName;
  final TotpAction onSubmit;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  State<TotpChallengeDialog> createState() => _TotpChallengeDialogState();
}

class _TotpChallengeDialogState extends State<TotpChallengeDialog> {
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

  bool get _isValid => RegExp(r'^\d{2,16}$').hasMatch(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      icon: const Icon(Icons.phonelink_lock),
      title: const Text('输入动态验证码'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.connectionName),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('totp-code-field'),
              controller: _controller,
              enabled: !widget.isSubmitting,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: InputDecoration(
                labelText: 'TOTP 验证码',
                errorText: widget.errorMessage,
              ),
              onSubmitted: _isValid && !widget.isSubmitting
                  ? (_) => widget.onSubmit(_controller.text)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _isValid && !widget.isSubmitting
              ? () => widget.onSubmit(_controller.text)
              : null,
          icon: widget.isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('验证'),
        ),
      ],
    );
  }
}
