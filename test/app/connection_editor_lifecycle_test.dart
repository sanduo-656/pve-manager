import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/app/app_controller.dart';
import 'package:pve_manager/app/connection_editor_page.dart';
import 'package:pve_manager/features/connections/data/connection_store.dart';
import 'package:pve_manager/presentation/connections/connection_form.dart';
import 'package:pve_manager/presentation/view_models.dart';

const _value = ConnectionFormValue(
  name: 'Lab',
  host: 'pve.example',
  port: 8006,
  username: 'operator',
  realm: 'pve',
  password: 'fixture',
  rememberPassword: false,
);

void main() {
  Future<ConnectionForm> show(
    WidgetTester tester,
    _ControlledController controller,
  ) async {
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ConnectionEditorPage(controller: controller)),
    );
    return tester.widget<ConnectionForm>(find.byType(ConnectionForm));
  }

  testWidgets('an unexpected TOTP error releases the editor from its dialog', (
    tester,
  ) async {
    final controller = _ControlledController();
    controller.begin = () async =>
        const ConnectionFlowNeedsTotp(availableMethods: {'totp'});
    controller.totp = (_) async => throw StateError('sensitive fixture');
    final form = await show(tester, controller);
    final result = form.onTest!(_value);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('totp-code-field')),
      '012345',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));
    await tester.pump();
    await result;
    await tester.pumpAndSettle();
    final updated = tester.widget<ConnectionForm>(find.byType(ConnectionForm));
    expect(updated.isTesting, isFalse);
    expect(updated.statusMessage, '动态验证码验证未完成，请重试。');
    expect(find.textContaining('sensitive fixture'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unexpected connection error releases busy state safely', (
    tester,
  ) async {
    final controller = _ControlledController();
    controller.begin = () async => throw StateError('sensitive fixture');
    final form = await show(tester, controller);
    await form.onTest!(_value);
    await tester.pump();
    final updated = tester.widget<ConnectionForm>(find.byType(ConnectionForm));
    expect(updated.isTesting, isFalse);
    expect(updated.isSubmitting, isFalse);
    expect(updated.statusMessage, '连接未完成，请重试。');
    expect(find.textContaining('sensitive fixture'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a second action before the next frame cannot replace a connection attempt',
    (tester) async {
      final controller = _ControlledController();
      final attempt = Completer<ConnectionFlowResult>();
      controller.begin = () => attempt.future;
      final form = await show(tester, controller);
      final first = form.onTest!(_value);
      await form.onSubmit(_value);
      expect(controller.attempts, 1);
      attempt.complete(const ConnectionFlowSucceeded(saved: false));
      await first;
      await tester.pump();
      expect(
        tester.widget<ConnectionForm>(find.byType(ConnectionForm)).isTesting,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'route disposal while failed test cancellation waits does not call setState',
    (tester) async {
      final controller = _ControlledController();
      final cancellation = Completer<void>();
      controller.begin = () async => const ConnectionFlowFailed('连接测试失败');
      controller.cancel = () => cancellation.future;
      final form = await show(tester, controller);
      final result = form.onTest!(_value);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      cancellation.complete();
      await result;
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

class _ControlledController extends AppController {
  _ControlledController()
    : super(
        store: ConnectionStore(
          metadataStore: _MemoryStorage(),
          secretStore: _MemoryStorage(),
        ),
      );

  Future<ConnectionFlowResult> Function() begin = () async =>
      const ConnectionFlowSucceeded(saved: false);
  Future<void> Function() cancel = () async {};
  Future<ConnectionFlowResult> Function(String) totp = (_) async =>
      const ConnectionFlowSucceeded(saved: false);
  int attempts = 0;

  @override
  Future<ConnectionFlowResult> beginConnection(
    ConnectionFormValue value, {
    String? connectionId,
    bool saveOnSuccess = true,
  }) {
    attempts++;
    return begin();
  }

  @override
  Future<void> cancelPendingConnection({bool notify = true}) =>
      notify ? cancel() : Future.value();

  @override
  Future<ConnectionFlowResult> submitPendingTotp(String code) => totp(code);
}

class _MemoryStorage implements ProfileMetadataStore, SecretStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}
