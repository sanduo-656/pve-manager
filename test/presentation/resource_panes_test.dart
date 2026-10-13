import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/presentation/resources/resource_detail_pane.dart';
import 'package:pve_manager/presentation/resources/resource_list_pane.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';

void main() {
  test('connection endpoint brackets an IPv6 host', () {
    const connection = ConnectionViewModel(
      id: 'lab',
      name: 'Lab',
      host: '2001:db8::1',
      port: 8006,
      username: 'operator',
      realm: 'pve',
      status: ConnectionStatus.connected,
      certificateStatus: CertificateStatus.systemTrusted,
    );
    expect(connection.endpoint, 'https://[2001:db8::1]:8006');
  });

  test('invalid usage remains unknown instead of a fabricated zero', () {
    expect(formatPercent(-0.1), '—');
    expect(formatPercent(double.nan), '—');
    expect(formatPercent(double.infinity), '—');
    expect(formatPercent(null), '—');
    expect(formatPercent(0), '0%');
  });

  const permissions = ResourceCapabilitiesViewModel(
    canPower: true,
    canConsole: true,
  );
  const running = ResourceViewModel(
    id: 'pve-a/qemu/100',
    connectionId: 'pve-a',
    connectionName: '生产集群',
    nodeName: 'pve01',
    guestId: '100',
    name: 'erp-server',
    kind: ResourceKind.qemu,
    status: ResourceStatus.running,
    cpuUsage: 0.24,
    memoryUsedBytes: 4294967296,
    memoryTotalBytes: 8589934592,
    capabilities: permissions,
  );
  const stopped = ResourceViewModel(
    id: 'pve-a/lxc/201',
    connectionId: 'pve-a',
    connectionName: '生产集群',
    nodeName: 'pve02',
    guestId: '201',
    name: 'staging-web',
    kind: ResourceKind.lxc,
    status: ResourceStatus.stopped,
    capabilities: permissions,
  );

  Widget app(Widget child) {
    return MaterialApp(
      theme: PveTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('keeps successful resources visible with a partial error', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ResourceListPane(
          resources: const [running],
          connections: const [
            ConnectionOptionViewModel(id: 'pve-a', name: '生产集群'),
            ConnectionOptionViewModel(id: 'pve-b', name: '灾备集群'),
          ],
          filter: const ResourceFilterViewModel(),
          onFilterChanged: (_) {},
          onResourceSelected: (_) {},
          partialErrors: const [
            ScopedErrorViewModel(
              id: 'pve-b',
              connectionId: 'pve-b',
              title: '灾备集群认证失效',
              message: '请重新登录后再刷新。',
            ),
          ],
        ),
      ),
    );

    expect(find.text('erp-server'), findsOneWidget);
    expect(find.text('灾备集群认证失效'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filter updates visible resources', (tester) async {
    var filter = const ResourceFilterViewModel();

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => ResourceListPane(
            resources: const [running, stopped],
            connections: const [
              ConnectionOptionViewModel(id: 'pve-a', name: '生产集群'),
            ],
            filter: filter,
            onFilterChanged: (next) => setState(() => filter = next),
            onResourceSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('erp-server'), findsOneWidget);
    expect(find.text('staging-web'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), '201');
    await tester.pump();

    expect(find.text('erp-server'), findsNothing);
    expect(find.text('staging-web'), findsOneWidget);
    expect(find.text('显示 1 / 2 台资源'), findsOneWidget);
  });

  testWidgets('compact type filters keep resource selection working', (
    tester,
  ) async {
    var filter = const ResourceFilterViewModel();
    ResourceViewModel? selected;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => ResourceListPane(
            resources: const [running, stopped],
            connections: const [
              ConnectionOptionViewModel(id: 'pve-a', name: '生产集群'),
            ],
            filter: filter,
            onFilterChanged: (next) => setState(() => filter = next),
            onResourceSelected: (resource) => selected = resource,
          ),
        ),
      ),
    );
    await tester.tap(find.text('容器'));
    await tester.pump();
    expect(find.text('erp-server'), findsNothing);
    expect(find.text('staging-web'), findsOneWidget);
    await tester.tap(find.text('staging-web'));
    expect(selected, same(stopped));
    await tester.tap(find.text('全部'));
    await tester.pump();
    expect(find.text('erp-server'), findsOneWidget);
    expect(find.text('staging-web'), findsOneWidget);
  });

  testWidgets('start calls back immediately without confirmation', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      app(
        ResourceDetailPane(
          resource: stopped,
          onStart: (_) => starts++,
          onShutdown: (_) {},
          onReboot: (_) {},
        ),
      ),
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, '开机'));
    await tester.tap(find.widgetWithText(FilledButton, '开机'));
    await tester.pump();

    expect(starts, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('shutdown requires a regular confirmation', (tester) async {
    var shutdowns = 0;
    await tester.pumpWidget(
      app(
        ResourceDetailPane(resource: running, onShutdown: (_) => shutdowns++),
      ),
    );

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '正常关机'));
    await tester.tap(find.widgetWithText(OutlinedButton, '正常关机'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(shutdowns, 0);

    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '正常关机'),
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(shutdowns, 1);
  });
}
