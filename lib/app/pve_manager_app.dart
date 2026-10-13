import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/console/console.dart';
import '../presentation/presentation.dart';
import 'app_controller.dart';
import 'app_info.dart';
import 'connection_editor_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/connection/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ConnectionEditorPage(
          controller: ProviderScope.containerOf(
            context,
          ).read(appControllerProvider),
        ),
      ),
      GoRoute(
        path: '/connection/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final controller = ProviderScope.containerOf(
            context,
          ).read(appControllerProvider);
          final profile = controller.profileById(state.pathParameters['id']!);
          if (profile == null) return const _MissingConnectionPage();
          return ConnectionEditorPage(controller: controller, profile: profile);
        },
      ),
      GoRoute(
        path: '/console',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final launch = state.extra;
          if (launch is! ConsoleLaunch) return const _MissingConsolePage();
          return ConsoleScreen(
            title: launch.title,
            origin: launch.origin,
            ticket: launch.ticket,
            consoleType: launch.consoleType,
            node: launch.node,
            vmid: launch.vmid,
            pinnedSha256: launch.pinnedSha256,
          );
        },
      ),
    ],
  );
}

class PveManagerApp extends StatefulWidget {
  const PveManagerApp({super.key});

  @override
  State<PveManagerApp> createState() => _PveManagerAppState();
}

class _PveManagerAppState extends State<PveManagerApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: PveTheme.light(),
      themeMode: ThemeMode.light,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: PveTheme.background,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: PveTheme.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child!,
      ),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  int _shownNotice = -1;
  bool _openedInitialConnectionForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(appControllerProvider)
        .setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    _scheduleNotice(controller);
    _scheduleFirstConnection(controller);

    final hasCompactDetail = switch (controller.section) {
      AppSection.resources => controller.selectedResource != null,
      AppSection.nodes => controller.selectedNode != null,
      AppSection.connections => false,
    };
    return PopScope(
      canPop: !hasCompactDetail,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !hasCompactDetail) return;
        if (controller.section == AppSection.resources) {
          controller.selectResource(null);
        } else {
          controller.selectNode(null);
        }
      },
      child: AppShell(
        showAppBar: !hasCompactDetail,
        selectedSection: controller.section,
        onSectionSelected: controller.setSection,
        title: AppInfo.displayName,
        actions: <Widget>[
          if (controller.isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
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
              onPressed: controller.profiles.isEmpty
                  ? null
                  : controller.refreshAll,
              icon: const PveIcon(
                PveIconName.refreshCw,
                size: 20,
                color: Color(0xFF56647D),
              ),
            ),
        ],
        floatingActionButton: controller.section == AppSection.connections
            ? FloatingActionButton(
                tooltip: '新增连接',
                onPressed: () => context.push('/connection/new'),
                child: const Icon(Icons.add),
              )
            : null,
        body: switch (controller.section) {
          AppSection.resources => _ResourcesPage(controller: controller),
          AppSection.nodes => _NodesPage(controller: controller),
          AppSection.connections => _ConnectionsPage(controller: controller),
        },
      ),
    );
  }

  void _scheduleNotice(AppController controller) {
    if (controller.notice == null || controller.noticeSerial == _shownNotice) {
      return;
    }
    _shownNotice = controller.noticeSerial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller.notice == null) return;
      final colors = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(controller.notice!),
            backgroundColor: controller.noticeIsError
                ? colors.error
                : colors.inverseSurface,
          ),
        );
    });
  }

  void _scheduleFirstConnection(AppController controller) {
    if (_openedInitialConnectionForm ||
        controller.isInitializing ||
        controller.profiles.isNotEmpty) {
      return;
    }
    _openedInitialConnectionForm = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.push('/connection/new');
    });
  }
}

class _ResourcesPage extends StatelessWidget {
  const _ResourcesPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final resources = controller.resourceViewModels;
    final selected = controller.selectedResource;
    return AdaptiveMasterDetail(
      showDetailOnCompact: selected != null,
      master: ResourceListPane(
        lastUpdatedAt: controller.lastUpdatedAtFor(
          controller.resourceFilter.connectionId,
        ),
        connectionOnline: controller.connectionIsOnline(
          controller.resourceFilter.connectionId,
        ),
        resources: resources,
        connections: controller.connectionOptions,
        filter: controller.resourceFilter,
        onFilterChanged: controller.setResourceFilter,
        onResourceSelected: controller.selectResource,
        selectedResourceId: controller.selectedResourceId,
        state: controller.resourcesPaneState,
        partialErrors: controller.partialErrors,
        onStateAction: () => _openConnections(context, controller),
        onRetryPartialErrors: controller.refreshAll,
        onRefresh: controller.refreshAll,
      ),
      detail: ResourceDetailPane(
        resource: selected,
        onBack: () => controller.selectResource(null),
        onStart: (item) =>
            controller.runResourceAction(item, ResourcePowerAction.start),
        onShutdown: (item) =>
            controller.runResourceAction(item, ResourcePowerAction.shutdown),
        onReboot: (item) =>
            controller.runResourceAction(item, ResourcePowerAction.reboot),
        onOpenConsole: (item) async {
          final launch = await controller.consoleLaunchFor(item);
          if (launch != null && context.mounted) {
            await context.push('/console', extra: launch);
          }
        },
      ),
    );
  }
}

class _NodesPage extends StatelessWidget {
  const _NodesPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedNode;
    return AdaptiveMasterDetail(
      showDetailOnCompact: selected != null,
      master: NodeListPane(
        lastUpdatedAt: controller.lastUpdatedAtFor(
          controller.nodeFilter.connectionId,
        ),
        connectionOnline: controller.connectionIsOnline(
          controller.nodeFilter.connectionId,
        ),
        nodes: controller.nodeViewModels,
        connections: controller.connectionOptions,
        filter: controller.nodeFilter,
        onFilterChanged: controller.setNodeFilter,
        onNodeSelected: controller.selectNode,
        selectedNodeId: controller.selectedNodeId,
        state: controller.nodesPaneState,
        partialErrors: controller.partialErrors,
        onStateAction: () => _openConnections(context, controller),
        onRetryPartialErrors: controller.refreshAll,
        onRefresh: controller.refreshAll,
      ),
      detail: NodeDetailPane(
        node: selected,
        monitoring: controller.selectedNodeMonitoring,
        onMonitoringTimeframeChanged: controller.setNodeMonitoringTimeframe,
        onRefreshMonitoring: () =>
            controller.refreshNodeMonitoring(forceHistory: true),
        onBack: () => controller.selectNode(null),
        onShutdown: (item) =>
            controller.runNodeAction(item, NodePowerAction.shutdown),
        onReboot: (item) =>
            controller.runNodeAction(item, NodePowerAction.reboot),
      ),
    );
  }
}

class _ConnectionsPage extends StatelessWidget {
  const _ConnectionsPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ConnectionsPane(
      connections: controller.connectionViewModels,
      state: controller.connectionsPaneState,
      partialErrors: controller.partialErrors,
      onAdd: () => context.push('/connection/new'),
      onStateAction: () => context.push('/connection/new'),
      onRetryPartialErrors: controller.refreshAll,
      onEdit: (connection) => context.push('/connection/${connection.id}'),
      onRelogin: (connection) => context.push('/connection/${connection.id}'),
      onTest: (connection) async {
        final profile = controller.profileById(connection.id);
        if (profile != null) {
          await context.push('/connection/${profile.id}');
        }
      },
      onDelete: (connection) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('删除 ${connection.name}？'),
            content: const Text('保存的密码和证书指纹也会从此设备删除。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await controller.deleteConnection(connection.id);
        }
      },
    );
  }
}

void _openConnections(BuildContext context, AppController controller) {
  controller.setSection(AppSection.connections);
}

class _MissingConnectionPage extends StatelessWidget {
  const _MissingConnectionPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('连接不存在')),
      body: const Center(child: Text('该 PVE 连接已被删除。')),
    );
  }
}

class _MissingConsolePage extends StatelessWidget {
  const _MissingConsolePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('无法打开控制台')),
      body: const Center(child: Text('控制台参数已失效，请返回资源页重试。')),
    );
  }
}
