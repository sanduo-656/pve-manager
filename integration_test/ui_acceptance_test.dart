import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pve_manager/presentation/resources/resource_detail_pane.dart';
import 'package:pve_manager/presentation/resources/resource_list_pane.dart';

import '../test/support/rt2w7_acceptance.dart';
import '../test/support/rt2w7_capture_contract.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'rt2w7 resources and R5YnD login with offline native touch',
    (tester) async {
      addTearDown(() => binding.setSurfaceSize(null));
      await tester.runAsync(
        () => loadRt2w7Fonts().timeout(const Duration(seconds: 30)),
      );
      final captures = <Map<String, Object>>[];
      binding.reportData = {
        'rt2w7': rt2w7CaptureNotes,
        'rt2w7Captures': captures,
      };
      var serial = 0;
      var boundaryKey = GlobalKey();

      Future<Rt2w7TapLog> show(Rt2w7Screen screen) async {
        final log = Rt2w7TapLog();
        boundaryKey = GlobalKey();
        await binding.setSurfaceSize(screen.viewport);
        await tester.pumpWidget(
          Rt2w7AcceptanceApp(
            key: ValueKey(++serial),
            screen: screen,
            boundaryKey: boundaryKey,
            log: log,
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.captureName} must not overflow.',
        );
        expect(tester.getSize(find.byKey(boundaryKey)), screen.viewport);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('acceptance-system-bar')))
              .height,
          52,
        );
        return log;
      }

      Future<void> capture(Rt2w7Screen screen) async {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        final bytes = await captureRt2w7Png(tester, boundaryKey);
        captures.add({
          'name': screen.captureName,
          'width': screen.viewport.width.toInt(),
          'height': screen.viewport.height.toInt(),
          'pixelRatio': 1,
          'bytes': bytes.toList(),
        });
        debugPrint('RT2W7_CAPTURE=${screen.captureName}');
      }

      Future<void> tapVisible(Finder target) async {
        expect(target, findsOneWidget);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        await tester.tap(target);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        expect(tester.takeException(), isNull);
      }

      await show(Rt2w7Screen.home);
      expect(find.text('Ubuntu Server'), findsOneWidget);
      expect(find.text('Home Assistant'), findsOneWidget);
      expect(find.text('Docker Services'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-navigation-bar')), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      await capture(Rt2w7Screen.home);
      await tapVisible(find.text('Ubuntu Server'));
      expect(find.byType(ResourceDetailPane), findsOneWidget);
      expect(find.byType(ResourceListPane), findsNothing);
      await tapVisible(find.byTooltip('返回资源列表'));
      expect(find.byType(ResourceListPane), findsOneWidget);

      var log = await show(Rt2w7Screen.detail);
      expect(find.text('23.4%'), findsOneWidget);
      expect(find.text('3.8 GiB'), findsOneWidget);
      await capture(Rt2w7Screen.detail);
      await tapVisible(find.widgetWithText(FilledButton, '打开控制台'));
      expect(log.console, 1);

      log = await show(Rt2w7Screen.form);
      expect(find.text('登录 PVE'), findsOneWidget);
      expect(find.text('8006 · Linux PAM'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-navigation-bar')), findsNothing);
      await capture(Rt2w7Screen.form);
      await tapVisible(find.byKey(const ValueKey('save-connection-button')));
      expect(log.connectionSave, 1);
      expect(log.savedConnection?.rememberPassword, isTrue);
      expect(log.savedConnection?.username, 'root');
      expect(log.savedConnection?.realm, 'pam');
      await tapVisible(
        find.byKey(const ValueKey('connection-advanced-toggle')),
      );
      expect(
        find.byKey(const ValueKey('connection-name-field')),
        findsOneWidget,
      );
      await tapVisible(find.byKey(const ValueKey('test-connection-button')));
      expect(log.connectionTest, 1);

      await show(Rt2w7Screen.wideHome);
      expect(find.byKey(const ValueKey('app-navigation-bar')), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(ResourceListPane), findsOneWidget);
      expect(find.byType(ResourceDetailPane), findsNothing);
      await capture(Rt2w7Screen.wideHome);
      await tapVisible(find.text('Ubuntu Server'));
      expect(find.byType(ResourceListPane), findsNothing);
      expect(find.byType(ResourceDetailPane), findsOneWidget);

      log = await show(Rt2w7Screen.wideDetail);
      expect(find.byKey(const ValueKey('app-navigation-bar')), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(ResourceListPane), findsNothing);
      await capture(Rt2w7Screen.wideDetail);
      await tapVisible(find.widgetWithText(FilledButton, '打开控制台'));
      expect(log.console, 1);
      expect(
        captures.map((capture) => capture['name']).toSet(),
        rt2w7CaptureSizes.keys.toSet(),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
