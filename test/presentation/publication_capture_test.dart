import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/app/app_info.dart';
import 'package:pve_manager/features/nodes/domain/pve_node_metrics.dart';
import 'package:pve_manager/presentation/app_shell.dart';
import 'package:pve_manager/presentation/nodes/node_detail_pane.dart';
import 'package:pve_manager/presentation/nodes/node_monitoring_pane.dart';
import 'package:pve_manager/presentation/nodes/node_monitoring_state.dart';
import 'package:pve_manager/presentation/resources/resource_list_pane.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';
import 'package:pve_manager/presentation/widgets/pve_icon.dart';

import '../support/rt2w7_acceptance.dart';

// Publication fixtures use production widgets and synthetic metrics only.
// No API client, credentials, certificate, or remote connection is created.
const _gib = 1024 * 1024 * 1024;
final _updatedAt = DateTime(2026, 10, 13, 9, 40);

NodeMonitoringState _demoMonitoring() => NodeMonitoringState(
  snapshot: const PveNodeMetricsSnapshot(
    cpuUsage: 0.318,
    ioWait: 0.014,
    cpuCount: 16,
    cpuModel: 'AMD Ryzen 7 · 演示设备',
    memoryUsedBytes: 12 * _gib,
    memoryTotalBytes: 32 * _gib,
    memoryAvailableBytes: 18 * _gib,
    swapUsedBytes: 256 * 1024 * 1024,
    swapTotalBytes: 8 * _gib,
    rootfsUsedBytes: 42 * _gib,
    rootfsTotalBytes: 100 * _gib,
    rootfsAvailableBytes: 58 * _gib,
    uptimeSeconds: 12 * 86400 + 5 * 3600,
    pveVersion: '8.4 · 演示环境',
    loadAverage: [1.82, 1.46, 1.21],
  ),
  points: List.generate(31, (i) {
    final pulse = math.sin(i * 0.55);
    final cpu = 0.31 + pulse * 0.13 + (i >= 12 && i <= 16 ? 0.19 : 0);
    return PveNodeRrdPoint(
      time: _updatedAt.subtract(Duration(minutes: (30 - i) * 2)),
      cpuUsage: cpu,
      ioWait: 0.014 + (math.sin(i * 0.3) + 1) * 0.01,
      memoryUsedBytes: (10.5 + math.sin(i * 0.12) * 1.5) * _gib,
      memoryTotalBytes: 32.0 * _gib,
      rootfsUsedBytes: (40 + i / 15) * _gib,
      rootfsTotalBytes: 100.0 * _gib,
      netInBytesPerSecond: (2.5 + (pulse + 1) * 2.1) * 1024 * 1024,
      netOutBytesPerSecond:
          (0.8 + (math.cos(i * 0.4) + 1) * 0.65) * 1024 * 1024,
    );
  }),
  storages: const [
    PveStorageStatus(
      id: 'local',
      type: 'dir',
      isActive: true,
      isEnabled: true,
      usedBytes: 42 * _gib,
      totalBytes: 100 * _gib,
      availableBytes: 58 * _gib,
    ),
    PveStorageStatus(
      id: 'local-lvm',
      type: 'lvmthin',
      isActive: true,
      isEnabled: true,
      usedBytes: 180 * _gib,
      totalBytes: 500 * _gib,
      availableBytes: 320 * _gib,
    ),
  ],
  snapshotUpdatedAt: _updatedAt,
  historyUpdatedAt: _updatedAt,
  storageUpdatedAt: _updatedAt,
);

Widget _app(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: PveTheme.light(),
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

Widget _resourceHome(GlobalKey boundary) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 52, bottom: 14),
      viewPadding: const EdgeInsets.only(top: 52, bottom: 14),
      textScaler: TextScaler.noScaling,
    ),
    child: RepaintBoundary(
      key: boundary,
      child: Stack(
        children: [
          AppShell(
            title: AppInfo.displayName,
            selectedSection: AppSection.resources,
            onSectionSelected: (_) {},
            actions: [
              IconButton(
                tooltip: '刷新',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(44),
                  maximumSize: const Size.square(44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                icon: const PveIcon(
                  PveIconName.refreshCw,
                  size: 20,
                  color: Color(0xFF56647D),
                ),
              ),
            ],
            body: ResourceListPane(
              resources: rt2w7Resources,
              connections: rt2w7ConnectionOptions,
              filter: const ResourceFilterViewModel(),
              onFilterChanged: (_) {},
              onResourceSelected: (_) {},
              lastUpdatedAt: DateTime.now(),
              onRefresh: () {},
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PublicationSystemBar(),
          ),
        ],
      ),
    ),
  ),
);

// Native status-bar illustration for publication screenshots only.
class _PublicationSystemBar extends StatelessWidget {
  const _PublicationSystemBar();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ColoredBox(
      color: const Color(0xFFF5F7FB),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '9:41',
              style: TextStyle(
                fontFamily: 'Inter',
                decoration: TextDecoration.none,
                fontSize: 14,
                height: 17 / 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF172239),
              ),
            ),
            Row(
              children: const [
                PveIcon(PveIconName.signal, size: 16, color: Color(0xFF172239)),
                SizedBox(width: 6),
                PveIcon(PveIconName.wifi, size: 16, color: Color(0xFF172239)),
                SizedBox(width: 6),
                PveIcon(
                  PveIconName.batteryFull,
                  size: 16,
                  color: Color(0xFF172239),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('exports safe publication resource and monitoring examples', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(loadRt2w7Fonts);
    final directory = Directory(
      Platform.environment['PVE_SCREENSHOT_DIR'] ?? 'build/publication',
    );

    Future<void> save(String name, GlobalKey boundary) async {
      expect(tester.takeException(), isNull);
      final bytes = await captureRt2w7Png(tester, boundary);
      await tester.runAsync(() async {
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes, flush: true);
      });
    }

    tester.view.physicalSize = const Size(390, 905);
    final resourceBoundary = GlobalKey();
    await tester.pumpWidget(_app(_resourceHome(resourceBoundary)));
    await tester.pumpAndSettle();
    expect(find.text(AppInfo.displayName), findsOneWidget);
    expect(find.text('Ubuntu Server'), findsOneWidget);
    await save('resource_home_demo', resourceBoundary);

    tester.view.physicalSize = const Size(390, 844);
    final phoneBoundary = GlobalKey();
    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: phoneBoundary,
          child: AppShell(
            selectedSection: AppSection.nodes,
            showAppBar: false,
            onSectionSelected: (_) {},
            body: NodeDetailPane(
              node: const NodeViewModel(
                id: 'demo/pve-01',
                connectionId: 'demo',
                connectionName: '家庭实验室 · 演示数据',
                name: 'pve-01',
                status: NodeStatus.online,
                capabilities: NodeCapabilitiesViewModel(canAudit: true),
                uptime: Duration(days: 12, hours: 5),
              ),
              monitoring: _demoMonitoring(),
              onBack: () {},
              onMonitoringTimeframeChanged: (_) {},
              onRefreshMonitoring: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('家庭实验室 · 演示数据'), findsNWidgets(2));
    expect(find.text('31.8%'), findsOneWidget);
    await save('node_monitoring_demo', phoneBoundary);

    tester.view.physicalSize = const Size(620, 2400);
    final fullBoundary = GlobalKey();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: RepaintBoundary(
              key: fullBoundary,
              child: NodeMonitoringPane(
                state: _demoMonitoring(),
                onTimeframeChanged: (_) {},
                onRefresh: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('local-lvm'), findsOneWidget);
    expect(find.byKey(const ValueKey('monitoring-chart-网络')), findsOneWidget);
    await save('node_monitoring_full_demo', fullBoundary);
  });
}
