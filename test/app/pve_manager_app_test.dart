import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/app/app_controller.dart';
import 'package:pve_manager/app/app_info.dart';
import 'package:pve_manager/app/pve_manager_app.dart';
import 'package:pve_manager/features/connections/data/connection_store.dart';
import 'package:pve_manager/presentation/presentation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rt2w7 stays light when the platform prefers dark', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final store = ConnectionStore(
      metadataStore: _MemoryMetadataStore(),
      secretStore: _MemorySecretStore(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(
            (ref) => AppController(store: store)..initialize(),
          ),
        ],
        child: const PveManagerApp(),
      ),
    );
    await tester.pumpAndSettle();
    final form = find.byType(ConnectionForm);
    expect(form, findsOneWidget);
    expect(Theme.of(tester.element(form)).brightness, Brightness.light);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(find.byKey(const ValueKey('acceptance-system-bar')), findsNothing);
    expect(find.text('9:41'), findsNothing);
  });

  testWidgets('empty install opens the first connection workflow', (
    tester,
  ) async {
    final store = ConnectionStore(
      metadataStore: _MemoryMetadataStore(),
      secretStore: _MemorySecretStore(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appControllerProvider.overrideWith((ref) {
            return AppController(store: store)..initialize();
          }),
        ],
        child: const PveManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录 PVE'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      AppInfo.name,
    );
    expect(find.byKey(const ValueKey('connection-host-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('connection-password-field')),
      findsOneWidget,
    );
  });

  testWidgets(
    'closing first connection workflow returns to the list without a provider build error',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = ConnectionStore(
        metadataStore: _MemoryMetadataStore(),
        secretStore: _MemorySecretStore(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appControllerProvider.overrideWith(
              (ref) => AppController(store: store)..initialize(),
            ),
          ],
          child: const PveManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('connection-host-field')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('connection-host-field')), findsNothing);
      expect(find.text('还没有 PVE 连接'), findsOneWidget);
      expect(find.text(AppInfo.displayName), findsOneWidget);
      expect(find.byKey(const ValueKey('app-navigation-bar')), findsOneWidget);
    },
  );
}

class _MemoryMetadataStore implements ProfileMetadataStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

class _MemorySecretStore implements SecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
