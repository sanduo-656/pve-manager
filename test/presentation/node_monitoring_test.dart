import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/features/nodes/domain/pve_node_metrics.dart';
import 'package:pve_manager/presentation/nodes/node_detail_pane.dart';
import 'package:pve_manager/presentation/nodes/node_monitoring_pane.dart';
import 'package:pve_manager/presentation/nodes/node_monitoring_state.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';

const _gib = 1024 * 1024 * 1024;
const _snapshot = PveNodeMetricsSnapshot(
  cpuUsage: 0.25,
  ioWait: 0.02,
  cpuCount: 8,
  cpuModel: 'Example processor with a long model name',
  memoryUsedBytes: 4 * _gib,
  memoryTotalBytes: 16 * _gib,
  memoryAvailableBytes: 10 * _gib,
  swapUsedBytes: 0,
  swapTotalBytes: 2 * _gib,
  rootfsUsedBytes: 20 * _gib,
  rootfsTotalBytes: 100 * _gib,
  rootfsAvailableBytes: 80 * _gib,
  loadAverage: [1, 0.8, 0.5],
);

List<PveNodeRrdPoint> _points() => [
  PveNodeRrdPoint(
    time: DateTime(2026, 10, 13, 10),
    cpuUsage: 0.25,
    ioWait: 0.02,
    memoryUsedBytes: 4 * _gib.toDouble(),
    memoryTotalBytes: 16 * _gib.toDouble(),
    rootfsUsedBytes: 20 * _gib.toDouble(),
    rootfsTotalBytes: 100 * _gib.toDouble(),
    netInBytesPerSecond: 1024,
    netOutBytesPerSecond: 512,
  ),
  // Keep this empty sample as a gap rather than a zero in every chart.
  PveNodeRrdPoint(time: DateTime(2026, 10, 13, 10, 1)),
  PveNodeRrdPoint(
    time: DateTime(2026, 10, 13, 10, 2),
    cpuUsage: 0.5,
    memoryUsedBytes: 8 * _gib.toDouble(),
    memoryTotalBytes: 16 * _gib.toDouble(),
    rootfsUsedBytes: 21 * _gib.toDouble(),
    rootfsTotalBytes: 100 * _gib.toDouble(),
    netInBytesPerSecond: 2048,
    netOutBytesPerSecond: 1024,
  ),
];

const _storages = [
  PveStorageStatus(
    id: 'local-storage-with-a-long-name',
    type: 'dir',
    isActive: true,
    isEnabled: true,
    usedBytes: 20 * _gib,
    totalBytes: 100 * _gib,
    availableBytes: 80 * _gib,
  ),
  PveStorageStatus(
    id: 'offline-backups',
    type: 'nfs',
    isActive: false,
    isEnabled: false,
  ),
];

ThemeData _theme(bool dark) => dark
    ? ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PveTheme.primaryBlue,
          brightness: Brightness.dark,
        ),
      )
    : PveTheme.light();

Widget _app(Widget child, {bool dark = false, double scale = 1}) => MaterialApp(
  theme: _theme(dark),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    ),
  ),
);

void main() {
  testWidgets(
    'empty sections explain missing data without fabricated zero values',
    (tester) async {
      await tester.pumpWidget(
        _app(const NodeMonitoringPane(state: NodeMonitoringState())),
      );

      expect(find.text('暂无节点状态数据'), findsOneWidget);
      expect(find.text('此时间范围暂无历史数据'), findsOneWidget);
      expect(find.text('暂无可见存储，需 Datastore.Audit 权限'), findsOneWidget);
      expect(find.text('0.0%'), findsNothing);
      expect(find.byKey(const ValueKey('monitoring-chart-CPU')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh errors preserve successful metrics and offer a retry', (
    tester,
  ) async {
    var retries = 0;
    final updatedAt = DateTime(2026, 10, 13, 10, 2);
    await tester.pumpWidget(
      _app(
        NodeMonitoringPane(
          state: NodeMonitoringState(
            snapshot: _snapshot,
            points: _points(),
            storages: _storages,
            snapshotError: '节点状态读取失败',
            historyError: '历史采样读取失败',
            storageError: '存储读取失败',
            snapshotUpdatedAt: updatedAt,
            historyUpdatedAt: updatedAt,
            storageUpdatedAt: updatedAt,
            isStale: true,
          ),
          onRefresh: () => retries++,
        ),
      ),
    );

    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('local-storage-with-a-long-name'), findsOneWidget);
    expect(find.textContaining('保留上次成功采集的数据。'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('node-monitoring-stale')), findsOneWidget);
    expect(find.text('更新于 2026-10-13 10:02'), findsNWidgets(3));
    await tester.tap(find.widgetWithText(TextButton, '重试').first);
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all missing samples have no trend line or zero summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        NodeMonitoringPane(
          state: NodeMonitoringState(
            points: [PveNodeRrdPoint(time: DateTime(2026, 10, 13))],
          ),
        ),
      ),
    );

    expect(find.text('此指标暂无历史数据'), findsNWidgets(4));
    expect(find.byKey(const ValueKey('monitoring-chart-CPU')), findsNothing);
    expect(find.textContaining('最近 0.0%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('time range selection invokes its callback', (tester) async {
    PveNodeTimeframe? selected;
    await tester.pumpWidget(
      _app(
        NodeMonitoringPane(
          state: const NodeMonitoringState(),
          onTimeframeChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('monitoring-timeframe-day')));
    await tester.pump();
    expect(selected, PveNodeTimeframe.day);
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 768.0]) {
      testWidgets(
        'monitoring fits width $width in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();

          await tester.pumpWidget(
            _app(
              NodeMonitoringPane(
                state: NodeMonitoringState(
                  snapshot: _snapshot,
                  points: _points(),
                  storages: _storages,
                ),
              ),
              dark: dark,
              scale: 1.5,
            ),
          );

          final title = tester.widget<Text>(find.text('资源概览'));
          final scheme = _theme(dark).colorScheme;
          expect(title.style?.color, scheme.onSurface);
          expect(
            find.textContaining('使用率：最近 50.0%，峰值 50.0%'),
            findsNWidgets(2),
          );
          expect(
            find.byKey(const ValueKey('monitoring-chart-CPU')),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('monitoring-chart-CPU')),
          );
          await tester.pump();
          expect(
            find.bySemanticsLabel(RegExp('CPU 历史趋势.*缺失采样以断线显示')),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('offline-backups'));
          await tester.pump();
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets(
    'node detail explains offline and audit permission restrictions',
    (tester) async {
      const node = NodeViewModel(
        id: 'connection/pve',
        connectionId: 'connection',
        connectionName: '生产集群',
        name: 'pve',
        status: NodeStatus.offline,
        capabilities: NodeCapabilitiesViewModel(canAudit: false),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: PveTheme.light(),
          home: const Scaffold(
            body: NodeDetailPane(node: node, monitoring: NodeMonitoringState()),
          ),
        ),
      );
      expect(find.text('当前账号没有节点监控权限，需要 Sys.Audit 权限。'), findsOneWidget);
      final chips = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('monitoring-timeframe-day')),
      );
      expect(chips.onSelected, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('node detail keeps its compact layout with monitoring', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const node = NodeViewModel(
      id: 'connection/pve',
      connectionId: 'connection',
      connectionName: '生产集群',
      name: 'pve',
      status: NodeStatus.online,
      capabilities: NodeCapabilitiesViewModel(canAudit: true),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: PveTheme.light(),
        home: Scaffold(
          body: NodeDetailPane(
            node: node,
            monitoring: NodeMonitoringState(
              snapshot: _snapshot,
              points: _points(),
              storages: _storages,
            ),
          ),
        ),
      ),
    );
    expect(find.text('资源概览'), findsOneWidget);
    expect(find.text('网络 · 最近采样'), findsOneWidget);
    await tester.ensureVisible(find.text('根分区').last);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
