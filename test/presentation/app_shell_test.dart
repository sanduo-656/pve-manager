import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/presentation/app_shell.dart';
import 'package:pve_manager/presentation/theme/pve_theme.dart';
import 'package:pve_manager/presentation/view_models.dart';
import 'package:pve_manager/presentation/widgets/adaptive_master_detail.dart';

void main() {
  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  for (final viewport in [
    const Size(390, 905),
    const Size(720, 1280),
    const Size(1200, 900),
  ]) {
    testWidgets('keeps the bottom capsule at ${viewport.width.toInt()}dp', (
      tester,
    ) async {
      await setViewport(tester, viewport);
      AppSection? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: PveTheme.light(),
          home: AppShell(
            selectedSection: AppSection.resources,
            onSectionSelected: (value) => selected = value,
            body: const Center(child: Text('内容')),
          ),
        ),
      );
      final capsule = find.byKey(const ValueKey('app-navigation-bar'));
      expect(capsule, findsOneWidget);
      expect(tester.getSize(capsule).height, 66);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('navigation-resources')))
            .height,
        52,
      );
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('节点'));
      expect(selected, AppSection.nodes);
      expect(tester.takeException(), isNull);
    });
  }

  for (final showDetail in [false, true]) {
    testWidgets('wide layouts show only ${showDetail ? 'detail' : 'list'}', (
      tester,
    ) async {
      await setViewport(tester, const Size(1200, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveMasterDetail(
              showDetailOnCompact: showDetail,
              master: const Text('列表'),
              detail: const Text('详情'),
            ),
          ),
        ),
      );
      expect(find.text('列表'), showDetail ? findsNothing : findsOneWidget);
      expect(find.text('详情'), showDetail ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
