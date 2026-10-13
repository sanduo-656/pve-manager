import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/presentation/connections/connection_form.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';
import 'package:pve_manager/presentation/widgets/pve_icon.dart';

import '../support/rt2w7_acceptance.dart';

const _example = ConnectionFormValue(
  name: '家庭实验室',
  host: '192.168.1.10',
  port: 8006,
  username: 'root',
  realm: 'pam',
  password: 'fixture-only',
  rememberPassword: true,
);

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _showLogin(
  WidgetTester tester, {
  ConnectionFormValue? initialValue,
  required ConnectionFormAction onSubmit,
  ConnectionFormAction? onTest,
  VoidCallback? onCancel,
  Size viewport = const Size(390, 844),
  double textScale = 1,
  double keyboardHeight = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  tester.view.padding = const FakeViewPadding(top: 52, bottom: 24);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      theme: PveTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: ConnectionForm(
          initialValue: initialValue,
          onSubmit: onSubmit,
          onTest: onTest,
          onCancel: onCancel,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('R5YnD login fits its 390x844 reference viewport', (
    tester,
  ) async {
    await tester.runAsync(loadRt2w7Fonts);
    await _showLogin(
      tester,
      initialValue: _example,
      onSubmit: (_) {},
      onTest: (_) {},
      onCancel: () {},
    );

    final title = find.text('登录 PVE');
    expect(title, findsOneWidget);
    expect(tester.getRect(title).left, 28);
    expect(tester.getRect(title).top, 80);
    final titleStyle = tester.widget<Text>(title).style!;
    expect(titleStyle.fontSize, 28);
    expect(titleStyle.fontWeight, FontWeight.w700);
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('8006 · Linux PAM'), findsOneWidget);
    final advancedChevron = find.descendant(
      of: _key('connection-advanced-toggle'),
      matching: find.byType(PveIcon),
    );
    expect(tester.getRect(advancedChevron).right, 362);
    expect(_key('connection-advanced-fields'), findsNothing);
    expect(_key('connection-name-field'), findsNothing);
    expect(_key('connection-port-field'), findsNothing);
    expect(_key('test-connection-button'), findsNothing);

    for (final name in [
      'connection-host-field',
      'connection-username-field',
      'connection-password-field',
    ]) {
      final field = _key(name);
      expect(field.hitTestable(), findsOneWidget);
      final rect = tester.getRect(field);
      expect(rect.left, 28);
      expect(rect.width, 334);
      expect(rect.height, closeTo(50, 0.1));
      final input = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(input.style.fontSize, 15);
    }
    for (final name in [
      'connection-advanced-toggle',
      'remember-password-switch',
      'save-connection-button',
    ]) {
      expect(_key(name).hitTestable(), findsOneWidget);
    }
    final loginButton = _key('save-connection-button');
    expect(tester.getRect(loginButton).left, 28);
    expect(tester.getRect(loginButton).width, 334);
    expect(tester.getRect(loginButton).height, 50);
    expect(find.text('登录'), findsOneWidget);
    expect(
      find.text('使用 HTTPS 连接；首次登录需验证服务器证书。').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh login defaults to PAM and does not remember a password', (
    tester,
  ) async {
    ConnectionFormValue? saved;
    await _showLogin(tester, onSubmit: (value) => saved = value);
    await tester.enterText(_key('connection-host-field'), ' pve.example ');
    await tester.enterText(_key('connection-username-field'), ' operator ');
    await tester.enterText(_key('connection-password-field'), ' fixture-only ');
    await _tap(tester, _key('save-connection-button'));

    expect(saved, isNotNull);
    expect(saved!.host, 'pve.example');
    expect(saved!.username, 'operator');
    expect(saved!.password, ' fixture-only ');
    expect(saved!.name, 'pve.example');
    expect(saved!.port, 8006);
    expect(saved!.realm, 'pam');
    expect(saved!.rememberPassword, isFalse);
  });

  testWidgets('collapsed settings retain the existing name and account', (
    tester,
  ) async {
    ConnectionFormValue? saved;
    await _showLogin(
      tester,
      initialValue: _example,
      onSubmit: (value) => saved = value,
    );
    await _tap(tester, _key('save-connection-button'));
    expect(saved!.name, '家庭实验室');
    expect(saved!.host, '192.168.1.10');
    expect(saved!.username, 'root');
    expect(saved!.realm, 'pam');
    expect(saved!.rememberPassword, isTrue);

    await _tap(tester, _key('connection-advanced-toggle'));
    expect(_key('connection-advanced-fields'), findsOneWidget);
    expect(_key('connection-name-field'), findsOneWidget);
    await tester.enterText(_key('connection-name-field'), '另一个实验室');
    await tester.enterText(_key('connection-port-field'), '8443');
    await _tap(tester, _key('connection-advanced-toggle'));
    expect(_key('connection-advanced-fields'), findsNothing);
    expect(find.text('8443 · Linux PAM'), findsOneWidget);
    await _tap(tester, _key('save-connection-button'));
    expect(saved!.name, '另一个实验室');
    expect(saved!.port, 8443);
  });

  testWidgets('remember option and advanced test emit only local callbacks', (
    tester,
  ) async {
    ConnectionFormValue? tested;
    ConnectionFormValue? saved;
    var closed = 0;
    await _showLogin(
      tester,
      initialValue: _example,
      onSubmit: (value) => saved = value,
      onTest: (value) => tested = value,
      onCancel: () => closed++,
    );
    await _tap(tester, _key('remember-password-switch'));
    await _tap(tester, _key('connection-advanced-toggle'));
    await _tap(tester, _key('test-connection-button'));
    expect(tested!.host, _example.host);
    expect(tested!.password, _example.password);
    expect(tested!.rememberPassword, isFalse);
    await _tap(tester, _key('save-connection-button'));
    expect(saved!.rememberPassword, isFalse);
    await _tap(tester, find.byTooltip('取消'));
    expect(closed, 1);
  });

  for (final textScale in [1.0, 1.7]) {
    testWidgets(
      'login is usable with a short keyboard viewport at $textScale',
      (tester) async {
        ConnectionFormValue? saved;
        ConnectionFormValue? tested;
        await _showLogin(
          tester,
          initialValue: _example,
          onSubmit: (value) => saved = value,
          onTest: (value) => tested = value,
          onCancel: () {},
          viewport: const Size(320, 640),
          textScale: textScale,
          keyboardHeight: 260,
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, find.byTooltip('显示密码'));
        expect(find.byTooltip('隐藏密码'), findsOneWidget);
        await _tap(tester, _key('save-connection-button'));
        expect(saved!.host, _example.host);
        await _tap(tester, _key('connection-advanced-toggle'));
        await tester.ensureVisible(_key('connection-name-field'));
        await tester.pumpAndSettle();
        await tester.enterText(_key('connection-name-field'), '键盘示例');
        await _tap(tester, _key('test-connection-button'));
        expect(tested!.name, '键盘示例');
        await _tap(tester, _key('save-connection-button'));
        expect(saved!.name, '键盘示例');
        expect(saved!.rememberPassword, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('required login errors remain visible and block the callback', (
    tester,
  ) async {
    var calls = 0;
    await _showLogin(tester, onSubmit: (_) => calls++);
    await _tap(tester, _key('save-connection-button'));
    expect(calls, 0);
    expect(find.text('请输入主机名或 IP'), findsOneWidget);
    expect(find.text('请输入用户名'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    expect(_key('save-connection-button').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
