import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/presentation/presentation.dart';

void main() {
  Widget app(Widget child) {
    return MaterialApp(
      theme: PveTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('node power action requires the exact node name', (tester) async {
    const node = NodeViewModel(
      id: 'pve-a/pve01',
      connectionId: 'pve-a',
      connectionName: '生产集群',
      name: 'pve01',
      status: NodeStatus.online,
      capabilities: NodeCapabilitiesViewModel(canPower: true),
    );
    var reboots = 0;

    await tester.pumpWidget(
      app(NodeDetailPane(node: node, onReboot: (_) => reboots++)),
    );
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '重启节点'));
    await tester.tap(find.widgetWithText(OutlinedButton, '重启节点'));
    await tester.pumpAndSettle();

    final confirmFinder = find.byKey(
      const ValueKey('confirm-node-power-action'),
    );
    FilledButton confirm = tester.widget(confirmFinder);
    expect(confirm.onPressed, isNull);

    final field = find.byKey(const ValueKey('node-name-confirmation-field'));
    await tester.enterText(field, 'PVE01');
    await tester.pump();
    confirm = tester.widget(confirmFinder);
    expect(confirm.onPressed, isNull);

    await tester.enterText(field, 'pve01');
    await tester.pump();
    confirm = tester.widget(confirmFinder);
    expect(confirm.onPressed, isNotNull);

    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();
    expect(reboots, 1);
  });

  testWidgets('TOTP passes leading zeroes as a string', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      app(
        TotpChallengeDialog(
          connectionName: '生产集群',
          onSubmit: (code) => submitted = code,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('totp-code-field')),
      '012345',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));

    expect(submitted, '012345');
  });

  testWidgets('TOTP accepts the PVE 2 to 16 digit range', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      app(
        TotpChallengeDialog(
          connectionName: '生产集群',
          onSubmit: (code) => submitted = code,
        ),
      ),
    );

    const code = '1234567890123456';
    await tester.enterText(find.byKey(const ValueKey('totp-code-field')), code);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '验证'));

    expect(submitted, code);
  });

  testWidgets('certificate change is rendered as a blocking warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CertificateApprovalPane(
          certificate: const CertificatePromptViewModel(
            endpoint: 'https://pve01.example:8006',
            previousFingerprint: 'AA:BB',
            sha256Fingerprint: 'CC:DD',
            isChanged: true,
          ),
          onApprove: () {},
          onReject: () {},
        ),
      ),
    );

    expect(find.text('服务器证书已变化'), findsOneWidget);
    expect(find.text('原 SHA-256 指纹'), findsOneWidget);
    expect(find.text('当前 SHA-256 指纹'), findsOneWidget);
    expect(find.text('确认并重新固定'), findsOneWidget);
  });
}
