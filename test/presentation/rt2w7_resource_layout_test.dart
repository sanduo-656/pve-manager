import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/presentation/resources/resource_detail_pane.dart';
import 'package:pve_manager/presentation/resources/resource_list_pane.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';
import 'package:pve_manager/presentation/widgets/inventory_widgets.dart';
import 'package:pve_manager/presentation/widgets/status_badge.dart';

void main() {
  const resource = ResourceViewModel(
    id: 'pve-a/qemu/101',
    connectionId: 'pve-a',
    connectionName: '家庭实验室',
    nodeName: 'pve-01',
    guestId: '101',
    name: 'Ubuntu Server',
    kind: ResourceKind.qemu,
    status: ResourceStatus.running,
    cpuUsage: .234,
    memoryUsedBytes: 4080218931,
    memoryTotalBytes: 8589934592,
    capabilities: ResourceCapabilitiesViewModel(
      canPower: true,
      canConsole: true,
    ),
  );
  Widget app(Widget child) => MaterialApp(
    theme: PveTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets('resource inventory matches rt2w7 mobile component dimensions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 905);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        ResourceListPane(
          resources: const [resource],
          connections: const [
            ConnectionOptionViewModel(id: 'pve-a', name: '家庭实验室'),
          ],
          filter: const ResourceFilterViewModel(),
          onFilterChanged: (_) {},
          onResourceSelected: (_) {},
          lastUpdatedAt: DateTime.now(),
          connectionOnline: true,
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(InventoryOverview)),
      const Size(346, 106),
    );
    expect(tester.getSize(find.byType(SearchBar)).height, 46);
    expect(tester.getTopLeft(find.text('搜索名称或 VMID')).dx, 64);
    final types = find.byType(InventoryTypeButton);
    expect(tester.getSize(types.at(0)), const Size(57, 36));
    expect(tester.getSize(types.at(1)), const Size(69, 36));
    expect(tester.getSize(types.at(2)), const Size(57, 36));
    final row = find
        .ancestor(
          of: find.text('Ubuntu Server'),
          matching: find.byType(InkWell),
        )
        .first;
    expect(tester.getSize(row), const Size(346, 111));
    expect(tester.getSize(find.byType(ResourceStatusBadge)).height, 16);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('刚刚更新'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resource detail matches rt2w7 spacing and action dimensions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 843);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        ResourceDetailPane(
          resource: resource,
          onBack: () {},
          onShutdown: (_) {},
          onReboot: (_) {},
          onOpenConsole: (_) {},
        ),
      ),
    );

    final metrics = find.byType(InventoryMetric);
    expect(tester.getSize(metrics.at(0)), const Size(167, 127));
    expect(tester.getSize(metrics.at(1)), const Size(167, 127));
    expect(tester.getTopLeft(metrics.at(0)), const Offset(22, 192));
    final metadata = find
        .ancestor(
          of: find.text('基本信息'),
          matching: find.byType(InventorySurface),
        )
        .first;
    expect(tester.getSize(metadata), const Size(346, 184));
    expect(tester.getTopLeft(metadata), const Offset(22, 341));
    expect(
      tester.getSize(find.widgetWithText(FilledButton, '打开控制台')).height,
      52,
    );
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, '正常关机')).height,
      48,
    );
    expect(find.text('关机与重启需要确认，并自动跟踪执行结果。'), findsOneWidget);
    expect(find.text('直通显卡且未配置虚拟显示设备时，图形控制台可能没有画面。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resource detail fills 640dp width with 22dp margins', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 843);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(ResourceDetailPane(resource: resource, onOpenConsole: (_) {})),
    );

    final metadata = find
        .ancestor(
          of: find.text('基本信息'),
          matching: find.byType(InventorySurface),
        )
        .first;
    final console = find.widgetWithText(FilledButton, '打开控制台');
    for (final component in [metadata, console]) {
      final rect = tester.getRect(component);
      expect(rect.width, 596);
      expect(rect.left, 22);
      expect(rect.right, 618);
    }
    expect(tester.takeException(), isNull);
  });
}
