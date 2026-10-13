import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/features/console/presentation/console_screen.dart';

void main() {
  const cookieChannel = MethodChannel('com.sanduo.pvemanager/webview_security');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  var cookieAttempts = 0;
  var rejectOrientation = false;
  var rejectDisplayMode = false;

  setUp(() {
    cookieAttempts = 0;
    rejectOrientation = false;
    rejectDisplayMode = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(cookieChannel, (
      call,
    ) async {
      if (call.method == 'setSecureCookie') {
        cookieAttempts++;
        throw PlatformException(
          code: 'cookie_rejected',
          message: 'Cookie rejected in test $cookieAttempts',
        );
      }
      return true;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if ((rejectOrientation &&
                call.method == 'SystemChrome.setPreferredOrientations') ||
            (rejectDisplayMode &&
                call.method == 'SystemChrome.setEnabledSystemUIMode')) {
          throw PlatformException(code: 'native_display_error');
        }
        return null;
      },
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      cookieChannel,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<void> openConsole(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const ConsoleScreen(
                    title: 'VM 101',
                    origin: 'https://pve.example:8006',
                    ticket: 'PVE:test-ticket',
                    consoleType: 'qemu',
                    node: 'pve',
                    vmid: 101,
                  ),
                ),
              ),
              child: const Text('Open console'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open console'));
    await tester.pumpAndSettle();
    expect(find.text('Cookie rejected in test 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('native initialization failure can be retried', (tester) async {
    await openConsole(tester);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(cookieAttempts, 2);
    expect(find.text('Cookie rejected in test 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('orientation failure is shown and the control can be retried', (
    tester,
  ) async {
    await openConsole(tester);
    rejectOrientation = true;
    await tester.tap(find.byTooltip('切换为横屏'));
    await tester.pumpAndSettle();

    expect(find.text('无法切换屏幕方向，请重试。'), findsOneWidget);
    expect(find.byTooltip('切换为横屏'), findsOneWidget);
    expect(tester.takeException(), isNull);

    rejectOrientation = false;
    await tester.tap(find.byTooltip('切换为横屏'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('切换为竖屏'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('immersive failure is shown without changing the toggle state', (
    tester,
  ) async {
    await openConsole(tester);
    rejectDisplayMode = true;
    await tester.tap(find.byTooltip('退出沉浸模式'));
    await tester.pumpAndSettle();

    expect(find.text('无法切换沉浸模式，请重试。'), findsOneWidget);
    expect(find.byTooltip('退出沉浸模式'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('native cleanup failures do not prevent leaving the console', (
    tester,
  ) async {
    await openConsole(tester);
    rejectOrientation = true;
    rejectDisplayMode = true;
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('Open console'), findsOneWidget);
    expect(find.text('VM 101'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
