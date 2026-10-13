import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../view_models.dart';
import '../widgets/feedback_views.dart';
import '../widgets/pve_icon.dart';

class ConnectionForm extends StatefulWidget {
  const ConnectionForm({
    super.key,
    required this.onSubmit,
    this.initialValue,
    this.onTest,
    this.onCancel,
    this.isSubmitting = false,
    this.isTesting = false,
    this.requirePassword = true,
    this.statusMessage,
    this.statusIsError = false,
    this.title,
    this.showHeader = true,
  });

  final ConnectionFormValue? initialValue;
  final ConnectionFormAction onSubmit;
  final ConnectionFormAction? onTest;
  final VoidCallback? onCancel;
  final bool isSubmitting;
  final bool isTesting;
  final bool requirePassword;
  final String? statusMessage;
  final bool statusIsError;
  final String? title;
  final bool showHeader;

  @override
  State<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<ConnectionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _realmController;
  late final TextEditingController _passwordController;
  late bool _rememberPassword;
  bool _obscurePassword = true;
  bool _advancedExpanded = false;

  bool get _busy => widget.isSubmitting || widget.isTesting;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue ?? ConnectionFormValue.defaults();
    _nameController = TextEditingController(text: initial.name);
    _hostController = TextEditingController(text: initial.host);
    _portController = TextEditingController(text: initial.port.toString());
    _usernameController = TextEditingController(text: initial.username);
    _realmController = TextEditingController(text: initial.realm);
    _passwordController = TextEditingController(text: initial.password);
    _rememberPassword = initial.rememberPassword;
    _portController.addListener(_refreshSummary);
    _realmController.addListener(_refreshSummary);
  }

  void _refreshSummary() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _realmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  ConnectionFormValue _value() {
    final host = _hostController.text.trim();
    final name = _nameController.text.trim();
    return ConnectionFormValue(
      name: name.isEmpty ? host : name,
      host: host,
      port: int.tryParse(_portController.text) ?? 8006,
      username: _usernameController.text.trim(),
      realm: _realmController.text.trim(),
      password: _passwordController.text,
      rememberPassword: _rememberPassword,
    );
  }

  void _run(ConnectionFormAction action) {
    if (_busy) return;
    // Advanced fields stay mounted while collapsed so their values and
    // validators survive toggling. Reveal them when a hidden value is invalid.
    if (_validatePort(_portController.text) != null ||
        _validateRealm(_realmController.text) != null) {
      setState(() => _advancedExpanded = true);
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    action(_value());
  }

  Future<void> _selectRealm(String value) async {
    if (_busy) return;
    if (value != 'custom') {
      _realmController.text = value;
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          _CustomRealmDialog(initialRealm: _realmController.text),
    );
    if (mounted && !_busy && result != null && result.isNotEmpty) {
      _realmController.text = result;
    }
  }

  String get _advancedSummary {
    final realm = _realmController.text.trim();
    final realmLabel = switch (realm) {
      'pam' => 'Linux PAM',
      'pve' => 'Proxmox VE',
      '' => '认证域',
      _ => realm,
    };
    return '${_portController.text} · $realmLabel';
  }

  String? _validatePort(String? value) {
    final port = int.tryParse(value ?? '');
    return port == null || port < 1 || port > 65535 ? '请输入 1–65535' : null;
  }

  String? _validateRealm(String? value) =>
      _usernameController.text.contains('@')
      ? null
      : _required('请输入认证域')(value);

  InputDecoration _inputDecoration({
    String? hint,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: _textStyle(15, const Color(0xFF8A94A8), height: 22 / 15),
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF8FAFD),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    constraints: const BoxConstraints(minHeight: 50),
    border: _inputBorder,
    enabledBorder: _inputBorder,
    disabledBorder: _inputBorder,
    focusedBorder: _inputBorder.copyWith(
      borderSide: const BorderSide(color: Color(0xFF3448C8)),
    ),
    errorBorder: _inputBorder.copyWith(
      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
    ),
    errorMaxLines: 3,
    errorStyle: _textStyle(
      11,
      Theme.of(context).colorScheme.error,
      height: 16 / 11,
    ),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 50),
  );

  static const _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Color(0xFFE2E7F0)),
  );

  @override
  Widget build(BuildContext context) {
    final fieldStyle = _textStyle(15, const Color(0xFF34415A), height: 22 / 15);
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.showHeader) ...[
                      _ConnectionHeader(
                        title: widget.title ?? '登录 PVE',
                        onCancel: _busy ? null : widget.onCancel,
                        showCancel: widget.onCancel != null,
                      ),
                      const SizedBox(height: 32),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        key: const ValueKey('connection-form-surface'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LabeledField(
                            label: '服务器地址',
                            child: TextFormField(
                              key: const ValueKey('connection-host-field'),
                              controller: _hostController,
                              enabled: !_busy,
                              style: fieldStyle,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: _inputDecoration(
                                hint: '192.168.1.10',
                              ),
                              validator: (value) {
                                final host = value?.trim() ?? '';
                                if (host.isEmpty) return '请输入主机名或 IP';
                                if (host.contains('://') ||
                                    host.contains('/')) {
                                  return '仅输入主机名或 IP，不含协议和路径';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 22),
                          _LabeledField(
                            label: '用户名',
                            child: TextFormField(
                              key: const ValueKey('connection-username-field'),
                              controller: _usernameController,
                              enabled: !_busy,
                              style: fieldStyle,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.username],
                              decoration: _inputDecoration(hint: 'root'),
                              validator: _required('请输入用户名'),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _LabeledField(
                            label: '密码',
                            child: TextFormField(
                              key: const ValueKey('connection-password-field'),
                              controller: _passwordController,
                              enabled: !_busy,
                              style: fieldStyle,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              autocorrect: false,
                              enableSuggestions: false,
                              onFieldSubmitted: (_) => _run(widget.onSubmit),
                              decoration: _inputDecoration(
                                hint: widget.requirePassword
                                    ? '登录密码'
                                    : '留空则不更改',
                                suffix: IconButton(
                                  tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                  padding: EdgeInsets.zero,
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 50),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                  icon: PveIcon(
                                    _obscurePassword
                                        ? PveIconName.eye
                                        : PveIconName.eyeOff,
                                    size: 20,
                                    color: const Color(0xFF8A94A8),
                                  ),
                                ),
                              ),
                              validator: widget.requirePassword
                                  ? _required('请输入密码')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _AdvancedToggle(
                            summary: _advancedSummary,
                            expanded: _advancedExpanded,
                            onTap: _busy
                                ? null
                                : () => setState(
                                    () =>
                                        _advancedExpanded = !_advancedExpanded,
                                  ),
                          ),
                          Offstage(
                            offstage: !_advancedExpanded,
                            child: Padding(
                              key: const ValueKey('connection-advanced-fields'),
                              padding: const EdgeInsets.only(top: 22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _FieldPair(
                                    leading: _LabeledField(
                                      label: '端口',
                                      child: TextFormField(
                                        key: const ValueKey(
                                          'connection-port-field',
                                        ),
                                        controller: _portController,
                                        enabled: !_busy,
                                        style: fieldStyle,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: _inputDecoration(),
                                        validator: _validatePort,
                                      ),
                                    ),
                                    trailing: _LabeledField(
                                      label: '认证域',
                                      help:
                                          'Linux 系统账号请选择 pam，也可直接填写 root@pam。',
                                      child: TextFormField(
                                        key: const ValueKey(
                                          'connection-realm-field',
                                        ),
                                        controller: _realmController,
                                        enabled: !_busy,
                                        style: fieldStyle,
                                        textInputAction: TextInputAction.next,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        decoration: _inputDecoration(
                                          suffix: PopupMenuButton<String>(
                                            key: const ValueKey(
                                              'connection-realm-menu',
                                            ),
                                            tooltip: '选择认证域',
                                            enabled: !_busy,
                                            padding: EdgeInsets.zero,
                                            icon: const PveIcon(
                                              PveIconName.chevronDown,
                                              size: 16,
                                              color: Color(0xFF8A94A8),
                                            ),
                                            onSelected: _selectRealm,
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'pam',
                                                child: Text('pam · Linux 系统账号'),
                                              ),
                                              PopupMenuItem(
                                                value: 'pve',
                                                child: Text(
                                                  'pve · Proxmox VE 账号',
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'custom',
                                                child: Text('自定义认证域…'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        validator: _validateRealm,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  _LabeledField(
                                    label: '连接名称',
                                    child: TextFormField(
                                      key: const ValueKey(
                                        'connection-name-field',
                                      ),
                                      controller: _nameController,
                                      enabled: !_busy,
                                      style: fieldStyle,
                                      textInputAction: TextInputAction.done,
                                      decoration: _inputDecoration(
                                        hint: '可选，默认使用服务器地址',
                                      ),
                                    ),
                                  ),
                                  if (widget.onTest != null) ...[
                                    const SizedBox(height: 14),
                                    TextButton(
                                      key: const ValueKey(
                                        'test-connection-button',
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : () => _run(widget.onTest!),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF3448C8,
                                        ),
                                        minimumSize: const Size.fromHeight(44),
                                        textStyle: _textStyle(
                                          13,
                                          const Color(0xFF3448C8),
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                      child: Text(
                                        widget.isTesting ? '正在测试…' : '测试连接',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _RememberPassword(
                            value: _rememberPassword,
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _rememberPassword = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      key: const ValueKey('save-connection-button'),
                      onPressed: _busy ? null : () => _run(widget.onSubmit),
                      style: FilledButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: const Color(0xFF3448C8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: _textStyle(
                          15,
                          Colors.white,
                          height: 22 / 15,
                          weight: FontWeight.w600,
                        ),
                      ),
                      child: Text(widget.isSubmitting ? '正在登录…' : '登录'),
                    ),
                    const SizedBox(height: 14),
                    const _FormHint(),
                    if (widget.statusMessage case final message?) ...[
                      const SizedBox(height: 18),
                      OperationNotice(
                        message: message,
                        isError: widget.statusIsError,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  FormFieldValidator<String> _required(String message) =>
      (value) => (value?.trim().isEmpty ?? true) ? message : null;
}

TextStyle _textStyle(
  double size,
  Color color, {
  double height = 1.4,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: 'Noto Sans SC',
  fontSize: size,
  color: color,
  height: height,
  fontWeight: weight,
  letterSpacing: 0,
);

class _CustomRealmDialog extends StatefulWidget {
  const _CustomRealmDialog({required this.initialRealm});
  final String initialRealm;

  @override
  State<_CustomRealmDialog> createState() => _CustomRealmDialogState();
}

class _CustomRealmDialogState extends State<_CustomRealmDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialRealm,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('自定义认证域'),
    content: TextField(
      key: const ValueKey('custom-realm-field'),
      controller: _controller,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration(labelText: '认证域名称'),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('确定'),
      ),
    ],
  );
}

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({
    required this.title,
    required this.onCancel,
    required this.showCancel,
  });
  final String title;
  final VoidCallback? onCancel;
  final bool showCancel;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: _textStyle(
                28,
                const Color(0xFF172239),
                height: 40 / 28,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '连接你的 Proxmox VE 服务器',
              style: _textStyle(13, const Color(0xFF68758C), height: 19 / 13),
            ),
          ],
        ),
      ),
      if (showCancel)
        IconButton(
          tooltip: '取消',
          onPressed: onCancel,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const PveIcon(
            PveIconName.x,
            size: 21,
            color: Color(0xFF68758D),
          ),
        ),
    ],
  );
}

class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.leading, required this.trailing});
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [leading, const SizedBox(height: 22), trailing],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: leading),
          const SizedBox(width: 14),
          Expanded(child: trailing),
        ],
      );
    },
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child, this.help});
  final String label;
  final Widget child;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: _textStyle(
        13,
        const Color(0xFF34415A),
        height: 19 / 13,
        weight: FontWeight.w500,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        help == null
            ? labelWidget
            : Tooltip(message: help!, child: labelWidget),
        const SizedBox(height: 9),
        Semantics(label: label, child: child),
      ],
    );
  }
}

class _AdvancedToggle extends StatelessWidget {
  const _AdvancedToggle({
    required this.summary,
    required this.expanded,
    required this.onTap,
  });
  final String summary;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: expanded,
    child: InkWell(
      key: const ValueKey('connection-advanced-toggle'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Text(
                  '高级设置',
                  style: _textStyle(
                    13,
                    const Color(0xFF34415A),
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.65,
                ),
                child: Text(
                  summary,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF68758C),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RotatedBox(
                quarterTurns: expanded ? 2 : 0,
                child: const PveIcon(
                  PveIconName.chevronDown,
                  size: 16,
                  color: Color(0xFF68758C),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FormHint extends StatelessWidget {
  const _FormHint();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 1.6),
        child: PveIcon(
          PveIconName.shieldCheck,
          size: 16,
          color: Color(0xFF6476BA),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          '使用 HTTPS 连接；首次登录需验证服务器证书。',
          style: _textStyle(12, const Color(0xFF68758C), height: 1.6),
        ),
      ),
    ],
  );
}

class _RememberPassword extends StatelessWidget {
  const _RememberPassword({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '记住密码',
    toggled: value,
    enabled: onChanged != null,
    child: InkWell(
      key: const ValueKey('remember-password-switch'),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '记住密码',
                style: _textStyle(
                  13,
                  const Color(0xFF34415A),
                  height: 19 / 13,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 40,
              height: 24,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF3448C8)
                    : const Color(0xFFD9DFEC),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: const SizedBox.square(
                dimension: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
