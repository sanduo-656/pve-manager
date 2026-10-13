import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pve_manager/presentation/app_shell.dart';
import 'package:pve_manager/presentation/connections/connection_form.dart';
import 'package:pve_manager/presentation/resources/resource_detail_pane.dart';
import 'package:pve_manager/presentation/resources/resource_list_pane.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';
import 'package:pve_manager/presentation/widgets/adaptive_master_detail.dart';
import 'package:pve_manager/presentation/widgets/pve_icon.dart';

import 'rt2w7_capture_contract.dart';

// This harness displays production widgets with fixed examples. It never
// instantiates an API client, an account session, or a credential store.
const rt2w7ConnectionOptions = [
  ConnectionOptionViewModel(id: 'visual-lab', name: '家庭实验室'),
];

const rt2w7Resources = [
  ResourceViewModel(
    id: 'visual-lab/qemu/101',
    connectionId: 'visual-lab',
    connectionName: '家庭实验室',
    nodeName: 'pve-01',
    guestId: '101',
    name: 'Ubuntu Server',
    kind: ResourceKind.qemu,
    status: ResourceStatus.running,
    cpuUsage: 0.234,
    memoryUsedBytes: 4080218932,
    memoryTotalBytes: 8589934592,
    capabilities: ResourceCapabilitiesViewModel(
      canPower: true,
      canConsole: true,
    ),
  ),
  ResourceViewModel(
    id: 'visual-lab/qemu/102',
    connectionId: 'visual-lab',
    connectionName: '家庭实验室',
    nodeName: 'pve-01',
    guestId: '102',
    name: 'Home Assistant',
    kind: ResourceKind.qemu,
    status: ResourceStatus.running,
    cpuUsage: 0.08,
    memoryUsedBytes: 687194767,
    memoryTotalBytes: 2147483648,
    capabilities: ResourceCapabilitiesViewModel(
      canPower: true,
      canConsole: true,
    ),
  ),
  ResourceViewModel(
    id: 'visual-lab/lxc/201',
    connectionId: 'visual-lab',
    connectionName: '家庭实验室',
    nodeName: 'pve-02',
    guestId: '201',
    name: 'Docker Services',
    kind: ResourceKind.lxc,
    status: ResourceStatus.stopped,
    capabilities: ResourceCapabilitiesViewModel(
      canPower: true,
      canConsole: true,
    ),
  ),
];

enum Rt2w7Screen { home, detail, form, wideHome, wideDetail }

extension Rt2w7ScreenViewport on Rt2w7Screen {
  String get captureName => switch (this) {
    Rt2w7Screen.home => 'rt2w7_home_390x905',
    Rt2w7Screen.detail => 'rt2w7_detail_390x843',
    Rt2w7Screen.form => 'r5ynd_login_390x844',
    Rt2w7Screen.wideHome => 'rt2w7_wide_home_720x1280',
    Rt2w7Screen.wideDetail => 'rt2w7_wide_detail_720x1280',
  };

  Size get viewport {
    final dimensions = rt2w7CaptureSizes[captureName]!;
    return Size(dimensions.width.toDouble(), dimensions.height.toDouble());
  }

  bool get showsDetail =>
      this == Rt2w7Screen.detail || this == Rt2w7Screen.wideDetail;
}

class Rt2w7TapLog {
  int console = 0;
  int start = 0;
  AppSection? navigationSelection;
  int connectionSave = 0;
  int connectionTest = 0;
  ConnectionFormValue? savedConnection;
}

Future<void> loadRt2w7Fonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<Uint8List> captureRt2w7Png(
  WidgetTester tester,
  GlobalKey boundaryKey,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  expect(
    bytes,
    isNotNull,
    reason: 'The actual Flutter widget raster must export.',
  );
  return bytes!;
}

class Rt2w7AcceptanceApp extends StatefulWidget {
  const Rt2w7AcceptanceApp({
    required this.screen,
    required this.boundaryKey,
    required this.log,
    super.key,
  });

  final Rt2w7Screen screen;
  final GlobalKey boundaryKey;
  final Rt2w7TapLog log;

  @override
  State<Rt2w7AcceptanceApp> createState() => _Rt2w7AcceptanceAppState();
}

class _Rt2w7AcceptanceAppState extends State<Rt2w7AcceptanceApp> {
  late ResourceViewModel? selectedResource = widget.screen.showsDetail
      ? rt2w7Resources.first
      : null;
  ResourceFilterViewModel resourceFilter = const ResourceFilterViewModel();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: PveTheme.light(),
    themeMode: ThemeMode.light,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      final bottomInset = widget.screen == Rt2w7Screen.form ? 24.0 : 14.0;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: widget.screen.viewport,
          padding: EdgeInsets.only(top: 52, bottom: bottomInset),
          viewPadding: EdgeInsets.only(top: 52, bottom: bottomInset),
          viewInsets: EdgeInsets.zero,
          textScaler: TextScaler.noScaling,
          platformBrightness: Brightness.light,
        ),
        child: RepaintBoundary(
          key: widget.boundaryKey,
          child: SizedBox.fromSize(
            size: widget.screen.viewport,
            child: Stack(
              children: [
                Positioned.fill(child: child!),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _AcceptanceSystemBar(
                    background: widget.screen == Rt2w7Screen.form
                        ? Colors.white
                        : const Color(0xFFF5F7FB),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    home: widget.screen == Rt2w7Screen.form
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
                rememberPassword: true,
              ),
              onCancel: () {},
              onSubmit: (value) {
                widget.log.connectionSave++;
                widget.log.savedConnection = value;
              },
              onTest: (_) => widget.log.connectionTest++,
            ),
          )
        : AppShell(
            selectedSection: AppSection.resources,
            // Reference captures cover resources/form only. Other destination
            // taps are recorded, without simulating unshown production pages.
            onSectionSelected: (value) =>
                widget.log.navigationSelection = value,
            showAppBar: selectedResource == null,
            actions: [
              Builder(
                builder: (context) => IconButton(
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
              ),
            ],
            body: AdaptiveMasterDetail(
              showDetailOnCompact: selectedResource != null,
              master: ResourceListPane(
                resources: rt2w7Resources,
                connections: rt2w7ConnectionOptions,
                filter: resourceFilter,
                onFilterChanged: (value) =>
                    setState(() => resourceFilter = value),
                onResourceSelected: (value) =>
                    setState(() => selectedResource = value),
                selectedResourceId: selectedResource?.id,
                lastUpdatedAt: DateTime.now(),
                onRefresh: () {},
              ),
              detail: ResourceDetailPane(
                resource: selectedResource,
                onBack: () => setState(() => selectedResource = null),
                onOpenConsole: (_) => widget.log.console++,
                onStart: (_) => widget.log.start++,
                onShutdown: (_) {},
                onReboot: (_) {},
              ),
            ),
          ),
  );
}

// This illustration belongs only to acceptance screenshots. It is deliberately
// outside all production widgets, whose status bar remains native Android UI.
class _AcceptanceSystemBar extends StatelessWidget {
  const _AcceptanceSystemBar({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('acceptance-system-bar'),
    height: 52,
    child: ColoredBox(
      color: background,
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
