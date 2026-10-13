import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pve_manager/app/app_info.dart';
import 'package:pve_manager/features/nodes/domain/pve_node_metrics.dart';
import 'package:pve_manager/presentation/app_shell.dart';
import 'package:pve_manager/presentation/connections/connection_form.dart';
import 'package:pve_manager/presentation/connections/connections_pane.dart';
import 'package:pve_manager/presentation/nodes/node_detail_pane.dart';
import 'package:pve_manager/presentation/nodes/node_list_pane.dart';
import 'package:pve_manager/presentation/nodes/node_monitoring_state.dart';
import 'package:pve_manager/presentation/resources/resource_detail_pane.dart';
import 'package:pve_manager/presentation/resources/resource_list_pane.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';

import 'rt2w7_acceptance.dart';

// Recording-only harness. Every panel is a production widget; all values and
// callbacks are local fixtures. No API client, session or credential store.
const _gib = 1024 * 1024 * 1024;
final _updatedAt = DateTime(2026, 10, 13, 9, 41);
const _node = NodeViewModel(
  id: 'visual-lab/pve-01',
  connectionId: 'visual-lab',
  connectionName: '家庭实验室 · 演示数据',
  name: 'pve-01',
  status: NodeStatus.online,
  cpuUsage: .318,
  memoryUsedBytes: 12 * _gib,
  memoryTotalBytes: 32 * _gib,
  uptime: Duration(days: 12, hours: 5),
  capabilities: NodeCapabilitiesViewModel(canAudit: true),
);

NodeMonitoringState promoMonitoring(PveNodeTimeframe timeframe) {
  final minutes = switch (timeframe) {
    PveNodeTimeframe.hour => 2,
    PveNodeTimeframe.day => 48,
    PveNodeTimeframe.week => 336,
    PveNodeTimeframe.month => 1440,
    PveNodeTimeframe.year => 17520,
  };
  return NodeMonitoringState(
    timeframe: timeframe,
    snapshot: const PveNodeMetricsSnapshot(
      cpuUsage: .318,
      ioWait: .014,
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
      final pulse = math.sin(i * .55);
      return PveNodeRrdPoint(
        time: _updatedAt.subtract(Duration(minutes: (30 - i) * minutes)),
        cpuUsage: .31 + pulse * .13 + (i >= 12 && i <= 16 ? .19 : 0),
        ioWait: .014 + (math.sin(i * .3) + 1) * .01,
        memoryUsedBytes: (10.5 + math.sin(i * .12) * 1.5) * _gib,
        memoryTotalBytes: 32.0 * _gib,
        rootfsUsedBytes: (40 + i / 15) * _gib,
        rootfsTotalBytes: 100.0 * _gib,
        netInBytesPerSecond: (2.5 + (pulse + 1) * 2.1) * 1024 * 1024,
        netOutBytesPerSecond:
            (0.8 + (math.cos(i * .4) + 1) * .65) * 1024 * 1024,
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
}

class PromoVideoApp extends StatefulWidget {
  const PromoVideoApp({super.key});

  @override
  State<PromoVideoApp> createState() => PromoVideoAppState();
}

class PromoVideoAppState extends State<PromoVideoApp> {
  AppSection section = AppSection.resources;
  ResourceFilterViewModel filter = const ResourceFilterViewModel();
  ResourceViewModel? resource;
  bool showNode = false;
  bool showLogin = false;
  PveNodeTimeframe timeframe = PveNodeTimeframe.hour;

  void home() => setState(() {
    section = AppSection.resources;
    resource = null;
    showNode = false;
    showLogin = false;
    filter = const ResourceFilterViewModel();
  });

  Widget _panel() => switch (section) {
    AppSection.resources =>
      resource == null
          ? ResourceListPane(
              resources: rt2w7Resources,
              connections: const [
                ConnectionOptionViewModel(
                  id: 'visual-lab',
                  name: '家庭实验室 · 演示数据',
                ),
              ],
              filter: filter,
              onFilterChanged: (value) => setState(() => filter = value),
              onResourceSelected: (value) => setState(() => resource = value),
              lastUpdatedAt: DateTime.now(),
              onRefresh: () {},
            )
          : ResourceDetailPane(
              resource: resource,
              onBack: () => setState(() => resource = null),
              onOpenConsole: (_) {},
              onStart: (_) {},
              onShutdown: (_) {},
              onReboot: (_) {},
            ),
    AppSection.nodes =>
      showNode
          ? NodeDetailPane(
              node: _node,
              onBack: () => setState(() => showNode = false),
              monitoring: promoMonitoring(timeframe),
              onMonitoringTimeframeChanged: (value) =>
                  setState(() => timeframe = value),
              onRefreshMonitoring: () {},
            )
          : NodeListPane(
              nodes: const [_node],
              connections: const [
                ConnectionOptionViewModel(
                  id: 'visual-lab',
                  name: '家庭实验室 · 演示数据',
                ),
              ],
              filter: const NodeFilterViewModel(),
              onFilterChanged: (_) {},
              onNodeSelected: (_) => setState(() => showNode = true),
              lastUpdatedAt: DateTime.now(),
              onRefresh: () {},
            ),
    AppSection.connections => ConnectionsPane(
      connections: const [
        ConnectionViewModel(
          id: 'visual-lab',
          name: '家庭实验室',
          host: '192.168.1.10',
          port: 8006,
          username: 'root',
          realm: 'pam',
          status: ConnectionStatus.connected,
          certificateStatus: CertificateStatus.pinned,
          detail: '离线演示数据',
        ),
        ConnectionViewModel(
          id: 'visual-office',
          name: '工作室',
          host: '192.168.20.10',
          port: 8006,
          username: 'operator',
          realm: 'pve',
          status: ConnectionStatus.connected,
          certificateStatus: CertificateStatus.systemTrusted,
          detail: '离线演示数据',
        ),
      ],
      onAdd: () => setState(() => showLogin = true),
      onEdit: (_) => setState(() => showLogin = true),
      onTest: (_) {},
      onRelogin: (_) {},
    ),
  };

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppInfo.name,
    debugShowCheckedModeBanner: false,
    theme: PveTheme.light(),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: showLogin
        ? Scaffold(
            backgroundColor: Colors.white,
            body: ConnectionForm(
              title: '登录 PVE',
              initialValue: const ConnectionFormValue(
                name: '家庭实验室',
                host: '192.168.1.10',
                port: 8006,
                username: 'root',
                realm: 'pam',
                password: 'fixture-only',
                rememberPassword: false,
              ),
              onCancel: () => setState(() => showLogin = false),
              onSubmit: (_) {},
              onTest: (_) {},
            ),
          )
        : AppShell(
            title: AppInfo.displayName,
            selectedSection: section,
            onSectionSelected: (value) => setState(() {
              section = value;
              resource = null;
              showNode = false;
            }),
            showAppBar: resource == null && !showNode,
            body: _panel(),
          ),
  );
}
