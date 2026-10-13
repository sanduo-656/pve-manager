import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/connections/domain/connection_profile.dart';
import '../presentation/connections/connection_form.dart';
import '../presentation/view_models.dart';
import '../presentation/widgets/security_prompts.dart';
import 'app_controller.dart';

class ConnectionEditorPage extends StatefulWidget {
  const ConnectionEditorPage({
    required this.controller,
    this.profile,
    super.key,
  });

  final AppController controller;
  final ConnectionProfile? profile;

  @override
  State<ConnectionEditorPage> createState() => _ConnectionEditorPageState();
}

class _ConnectionEditorPageState extends State<ConnectionEditorPage> {
  bool _submitting = false;
  bool _testing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _submit(ConnectionFormValue value) {
    return _run(value, saveOnSuccess: true);
  }

  Future<void> _test(ConnectionFormValue value) {
    return _run(value, saveOnSuccess: false);
  }

  Future<void> _run(
    ConnectionFormValue value, {
    required bool saveOnSuccess,
  }) async {
    if (_submitting || _testing) return;
    setState(() {
      _submitting = saveOnSuccess;
      _testing = !saveOnSuccess;
      _statusMessage = saveOnSuccess ? '正在验证并保存…' : '正在测试连接…';
      _statusIsError = false;
    });

    try {
      final result = await widget.controller.beginConnection(
        value,
        connectionId: widget.profile?.id,
        saveOnSuccess: saveOnSuccess,
      );
      await _driveFlow(result, saveOnSuccess: saveOnSuccess);
    } on Object {
      // An unexpected persistence/client failure must leave the editor usable.
      // Keep raw exception details out of the UI because they can contain
      // connection credentials or request contents.
      await widget.controller.cancelPendingConnection();
      if (mounted) {
        setState(() {
          _statusMessage = '连接未完成，请重试。';
          _statusIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _testing = false;
        });
      }
    }
  }

  Future<void> _driveFlow(
    ConnectionFlowResult initial, {
    required bool saveOnSuccess,
  }) async {
    var result = initial;
    while (mounted) {
      switch (result) {
        case ConnectionFlowSucceeded():
          if (saveOnSuccess) {
            if (!mounted) return;
            Navigator.of(context).pop(true);
          } else {
            setState(() {
              _statusMessage = '连接测试成功。';
              _statusIsError = false;
            });
          }
          return;
        case ConnectionFlowFailed(:final message):
          if (!saveOnSuccess) {
            await widget.controller.cancelPendingConnection();
          }
          if (!mounted) return;
          setState(() {
            _statusMessage = message;
            _statusIsError = true;
          });
          return;
        case ConnectionFlowNeedsCertificate(:final prompt):
          if (!mounted) return;
          final approved = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => Dialog.fullscreen(
              child: CertificateApprovalPane(
                certificate: prompt,
                onApprove: () => Navigator.pop(dialogContext, true),
                onReject: () => Navigator.pop(dialogContext, false),
              ),
            ),
          );
          if (approved != true) {
            await widget.controller.cancelPendingConnection();
            if (mounted) {
              setState(() {
                _statusMessage = '证书未确认，连接已阻止。';
                _statusIsError = true;
              });
            }
            return;
          }
          result = await widget.controller.approvePendingCertificate();
          continue;
        case ConnectionFlowNeedsTotp():
          final next = await _requestTotp();
          if (next == null) {
            await widget.controller.cancelPendingConnection();
            return;
          }
          result = next;
          continue;
      }
    }
  }

  Future<ConnectionFlowResult?> _requestTotp() {
    var submitting = false;
    String? errorMessage;
    final connectionName = widget.profile?.name ?? '新 PVE 连接';
    return showDialog<ConnectionFlowResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return TotpChallengeDialog(
            connectionName: connectionName,
            isSubmitting: submitting,
            errorMessage: errorMessage,
            onSubmit: (code) async {
              if (submitting) return;
              setDialogState(() {
                submitting = true;
                errorMessage = null;
              });
              ConnectionFlowResult result;
              try {
                result = await widget.controller.submitPendingTotp(code);
              } on Object {
                result = const ConnectionFlowFailed('动态验证码验证未完成，请重试。');
              }
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext, result);
            },
          );
        },
      ),
    );
  }

  Future<void> _cancel() async {
    await widget.controller.cancelPendingConnection();
    if (mounted) Navigator.pop(context, false);
  }

  @override
  void dispose() {
    // Invalidate this flow immediately; route disposal must not notify Riverpod
    // listeners while the widget tree is being finalized.
    unawaited(widget.controller.cancelPendingConnection(notify: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final busy = _submitting || _testing;
    return PopScope(
      canPop: !busy,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarDividerColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: ConnectionForm(
            title: profile == null ? '登录 PVE' : '编辑连接',
            onCancel: _cancel,
            initialValue: profile == null
                ? ConnectionFormValue.defaults()
                : widget.controller.formValueFor(profile),
            requirePassword: profile == null,
            isSubmitting: _submitting,
            isTesting: _testing,
            statusMessage: _statusMessage,
            statusIsError: _statusIsError,
            onSubmit: _submit,
            onTest: _test,
          ),
        ),
      ),
    );
  }
}
