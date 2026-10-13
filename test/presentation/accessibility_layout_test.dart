import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/app/app_info.dart';
import 'package:pve_manager/presentation/presentation.dart';

const _resource = ResourceViewModel(
  id: 'lab/qemu/100',
  connectionId: 'lab',
  connectionName: '家庭实验室',
  nodeName: 'pve01',
  guestId: '100',
  name: 'Ubuntu Server',
  kind: ResourceKind.qemu,
  status: ResourceStatus.running,
  cpuUsage: 0.25,
  memoryUsedBytes: 1024 * 1024 * 1024,
  memoryTotalBytes: 4 * 1024 * 1024 * 1024,
  capabilities: ResourceCapabilitiesViewModel(canPower: true, canConsole: true),
);

const _node = NodeViewModel(
  id: 'lab/pve01',
  connectionId: 'lab',
  connectionName: '家庭实验室',
  name: 'pve01',
  status: NodeStatus.online,
  capabilities: NodeCapabilitiesViewModel(canPower: true),
);

void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: PveTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: child,
      ),
    );
  }

  testWidgets('versioned app title and navigation fit at large font', (
    tester,
  ) async {
    await show(
      tester,
      AppShell(
        title: AppInfo.displayName,
        selectedSection: AppSection.resources,
        onSectionSelected: (_) {},
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
        ],
        body: const Text('内容'),
      ),
    );
    expect(find.text(AppInfo.displayName), findsOneWidget);
    expect(
      find.byKey(const ValueKey('navigation-resources')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resource filters and usage fit on a small large-font screen', (
    tester,
  ) async {
    await show(
      tester,
      Scaffold(
        body: ResourceListPane(
          resources: const [_resource],
          connections: const [
            ConnectionOptionViewModel(id: 'lab', name: '家庭实验室'),
          ],
          filter: const ResourceFilterViewModel(),
          onFilterChanged: (_) {},
          onResourceSelected: (_) {},
        ),
      ),
    );
    await tester.ensureVisible(find.text('Ubuntu Server'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resource detail actions fit on a small large-font screen', (
    tester,
  ) async {
    await show(
      tester,
      Scaffold(
        body: ResourceDetailPane(
          resource: _resource,
          onBack: () {},
          onShutdown: (_) {},
          onReboot: (_) {},
          onOpenConsole: (_) {},
        ),
      ),
    );
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '正常关机'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('node detail power actions fit on a small large-font screen', (
    tester,
  ) async {
    await show(
      tester,
      Scaffold(
        body: NodeDetailPane(
          node: _node,
          onBack: () {},
          onShutdown: (_) {},
          onReboot: (_) {},
        ),
      ),
    );
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '关闭节点'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('TOTP remains usable with large font and keyboard', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await show(
      tester,
      Scaffold(
        body: TotpChallengeDialog(
          connectionName: '家庭实验室生产集群',
          onSubmit: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('node name confirmation remains usable with keyboard', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await show(
      tester,
      const Scaffold(
        body: NodeNameConfirmationDialog(
          nodeName: 'pve-production-01',
          action: NodePowerAction.shutdown,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
