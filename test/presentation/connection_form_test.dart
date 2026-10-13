import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/app/app_controller.dart';
import 'package:pve_manager/app/connection_editor_page.dart';
import 'package:pve_manager/features/connections/data/connection_store.dart';
import 'package:pve_manager/presentation/connections/connection_form.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connection form remains usable at 360dp', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: PveTheme.light(),
        home: Scaffold(
          body: ConnectionForm(
            onSubmit: (_) {},
            onTest: (_) {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('登录 PVE'), findsOneWidget);
    expect(find.byKey(const ValueKey('connection-host-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection form validates and emits structured values', (
    tester,
  ) async {
    ConnectionFormValue? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: PveTheme.light(),
        home: Scaffold(
          body: ConnectionForm(onSubmit: (value) => submitted = value),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('connection-advanced-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('connection-name-field')),
      '生产集群',
    );
    await tester.enterText(
      find.byKey(const ValueKey('connection-host-field')),
      'pve01.example',
    );
    await tester.enterText(
      find.byKey(const ValueKey('connection-username-field')),
      'mobile-admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('connection-password-field')),
      'secret',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('save-connection-button')),
    );
    await tester.tap(find.byKey(const ValueKey('save-connection-button')));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.host, 'pve01.example');
    expect(submitted!.port, 8006);
    expect(submitted!.realm, 'pam');
    expect(submitted!.rememberPassword, isFalse);
  });

  testWidgets(
    'first-run save action is fully visible on the Android viewport',
    (tester) async {
      const pixelRatio = 420 / 160;
      tester.view.devicePixelRatio = pixelRatio;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.padding = const FakeViewPadding(top: 63, bottom: 63);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: PveTheme.light(),
          home: Scaffold(
            appBar: AppBar(toolbarHeight: 76, title: const Text('新增连接')),
            body: ConnectionForm(
              showHeader: false,
              onSubmit: (_) => submitted = true,
              onTest: (_) {},
            ),
          ),
        ),
      );

      final saveButton = find.byKey(const ValueKey('save-connection-button'));
      expect(saveButton.hitTestable(), findsOneWidget);
      expect(find.text('登录').hitTestable(), findsOneWidget);
      final rect = tester.getRect(saveButton);
      expect(rect.top, greaterThan(0));
      expect(rect.bottom, lessThanOrEqualTo((2400 - 63) / pixelRatio));
      await tester.tap(saveButton);
      await tester.pump();
      expect(submitted, isFalse);
      expect(find.text('请输入主机名或 IP'), findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      expect(saveButton.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final textScale in [1.0, 1.7]) {
    testWidgets(
      '320dp form can test and save with keyboard at $textScale text scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        ConnectionFormValue? tested;
        ConnectionFormValue? saved;
        await tester.pumpWidget(
          MaterialApp(
            theme: PveTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: ConnectionForm(
                onSubmit: (value) => saved = value,
                onTest: (value) => tested = value,
                onCancel: () {},
              ),
            ),
          ),
        );
        final advanced = find.byKey(
          const ValueKey('connection-advanced-toggle'),
        );
        await tester.ensureVisible(advanced);
        await tester.pumpAndSettle();
        await tester.tap(advanced);
        await tester.pumpAndSettle();
        const entries = {
          'connection-name-field': '家庭实验室',
          'connection-host-field': '192.168.1.10',
          'connection-username-field': 'mobile',
          'connection-realm-field': 'custom-ldap',
          'connection-password-field': 'test-password',
        };
        for (final entry in entries.entries) {
          final field = find.byKey(ValueKey(entry.key));
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, entry.value);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        final reveal = find.byTooltip('显示密码');
        await tester.ensureVisible(reveal);
        await tester.pumpAndSettle();
        await tester.tap(reveal);
        await tester.pumpAndSettle();
        expect(find.byTooltip('隐藏密码'), findsOneWidget);

        final testButton = find.widgetWithText(TextButton, '测试连接');
        await tester.ensureVisible(testButton);
        await tester.pumpAndSettle();
        await tester.tap(testButton);
        await tester.pumpAndSettle();
        expect(tested?.host, '192.168.1.10');
        expect(tested?.realm, 'custom-ldap');
        expect(tested?.password, 'test-password');
        expect(tested?.rememberPassword, isFalse);

        final saveButton = find.byKey(const ValueKey('save-connection-button'));
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        expect(saved?.name, '家庭实验室');
        expect(saved?.port, 8006);
        expect(saved?.realm, 'custom-ldap');
        expect(saved?.rememberPassword, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '390x844 login keeps advanced fields collapsed and scrolls errors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 52);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: PveTheme.light(),
          home: Scaffold(
            body: ConnectionForm(
              onSubmit: (_) {},
              onTest: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );
      final surface = find.byKey(const ValueKey('connection-form-surface'));
      final save = find.byKey(const ValueKey('save-connection-button'));
      expect(tester.getRect(surface).left, 28);
      expect(tester.getRect(surface).width, 334);
      final initialHeight = tester.getRect(surface).height;
      for (final fieldKey in [
        'connection-host-field',
        'connection-username-field',
        'connection-password-field',
      ]) {
        final field = find.byKey(ValueKey(fieldKey));
        expect(
          field.hitTestable(),
          findsOneWidget,
          reason:
              'All fields are visible without scrolling at the reference size.',
        );
        expect(tester.getRect(field).height, closeTo(50, 0.1));
      }
      for (final fieldKey in [
        'connection-name-field',
        'connection-port-field',
        'connection-realm-field',
      ]) {
        expect(find.byKey(ValueKey(fieldKey)), findsNothing);
      }
      expect(
        find.byKey(const ValueKey('test-connection-button')),
        findsNothing,
      );
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getRect(save).height, 50);
      await tester.tap(save);
      await tester.pump();
      expect(find.text('请输入主机名或 IP'), findsOneWidget);
      expect(find.text('请输入用户名'), findsOneWidget);
      expect(find.text('请输入密码'), findsOneWidget);
      expect(
        tester.getRect(surface).height,
        greaterThan(initialHeight),
        reason: 'Validation errors grow the form rather than being clipped.',
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('realm choices support pam and a custom domain', (tester) async {
    ConnectionFormValue? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: PveTheme.light(),
        home: Scaffold(
          body: ConnectionForm(
            initialValue: const ConnectionFormValue(
              name: 'Lab',
              host: 'pve.example',
              port: 8006,
              username: 'operator',
              realm: 'pve',
              password: 'fixture',
              rememberPassword: false,
            ),
            onSubmit: (value) => saved = value,
          ),
        ),
      ),
    );
    final advanced = find.byKey(const ValueKey('connection-advanced-toggle'));
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('connection-realm-menu'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('pam · Linux 系统账号'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-connection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-connection-button')));
    await tester.pump();
    expect(saved?.realm, 'pam');

    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义认证域…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('custom-realm-field')),
      'corporate-ldap',
    );
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-connection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-connection-button')));
    await tester.pump();
    expect(saved?.realm, 'corporate-ldap');
    expect(saved?.rememberPassword, isFalse);
    await tester.ensureVisible(
      find.byKey(const ValueKey('remember-password-switch')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remember-password-switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-connection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-connection-button')));
    await tester.pump();
    expect(saved?.rememberPassword, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid advanced values are revealed before login', (
    tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PveTheme.light(),
        home: Scaffold(
          body: ConnectionForm(
            initialValue: const ConnectionFormValue(
              name: 'Lab',
              host: 'pve.example',
              port: 8006,
              username: 'operator',
              realm: 'pam',
              password: 'fixture',
              rememberPassword: false,
            ),
            onSubmit: (_) => submitted = true,
          ),
        ),
      ),
    );
    final advanced = find.byKey(const ValueKey('connection-advanced-toggle'));
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    final port = find.byKey(const ValueKey('connection-port-field'));
    await tester.ensureVisible(port);
    await tester.pumpAndSettle();
    await tester.enterText(port, '0');
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(port, findsNothing);
    final login = find.byKey(const ValueKey('save-connection-button'));
    await tester.ensureVisible(login);
    await tester.pumpAndSettle();
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
    expect(port, findsOneWidget);
    expect(find.text('请输入 1–65535'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'connection editor reuses one header and closes back to its caller',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 886);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      // No initialization or connection attempt: the controller only handles
      // local cancellation when this empty editor route closes.
      final memory = _MemoryConnectionStorage();
      final controller = AppController(
        store: ConnectionStore(metadataStore: memory, secretStore: memory),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: PveTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ConnectionEditorPage(controller: controller),
                    ),
                  ),
                  child: const Text('打开连接编辑器'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开连接编辑器'));
      await tester.pumpAndSettle();
      expect(find.text('登录 PVE'), findsOneWidget);
      expect(find.text('连接你的 Proxmox VE 服务器'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(ConnectionEditorPage),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(overlay.value.statusBarColor, Colors.white);
      expect(overlay.value.statusBarIconBrightness, Brightness.dark);
      expect(overlay.value.systemNavigationBarColor, Colors.white);
      expect(overlay.value.systemNavigationBarIconBrightness, Brightness.dark);
      expect(overlay.value.systemStatusBarContrastEnforced, isFalse);
      expect(overlay.value.systemNavigationBarContrastEnforced, isFalse);
      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(ConnectionEditorPage),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, Colors.white);
      expect(
        find.byKey(const ValueKey('save-connection-button')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connection-name-field')), findsNothing);
      expect(find.text('打开连接编辑器').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryConnectionStorage implements ProfileMetadataStore, SecretStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
