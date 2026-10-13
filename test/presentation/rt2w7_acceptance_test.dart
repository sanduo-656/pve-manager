import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/presentation/connections/connection_form.dart';
import 'package:pve_manager/presentation/resources/resource_detail_pane.dart';
import 'package:pve_manager/presentation/resources/resource_list_pane.dart';

import '../support/rt2w7_acceptance.dart';
import '../support/rt2w7_capture_contract.dart';

void main() {
  testWidgets(
    'exports rt2w7 resources and R5YnD login at reference pixel sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.runAsync(loadRt2w7Fonts);
      final directory = Directory(
        Platform.environment['PVE_SCREENSHOT_DIR'] ?? 'build/rt2w7/screenshots',
      );
      final manifest = <Map<String, Object>>[];

      for (final screen in Rt2w7Screen.values) {
        tester.view.physicalSize = screen.viewport;
        final key = GlobalKey();
        await tester.pumpWidget(
          Rt2w7AcceptanceApp(
            key: ValueKey(screen),
            screen: screen,
            boundaryKey: key,
            log: Rt2w7TapLog(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.captureName} must not overflow.',
        );
        expect(tester.getSize(find.byKey(key)), screen.viewport);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('acceptance-system-bar')))
              .height,
          52,
        );
        expect(find.text('9:41'), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        if (screen == Rt2w7Screen.form) {
          expect(find.byType(ConnectionForm), findsOneWidget);
          expect(find.text('登录 PVE'), findsOneWidget);
          expect(find.text('8006 · Linux PAM'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('connection-name-field')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('save-connection-button')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('app-navigation-bar')),
            findsNothing,
          );
        } else {
          expect(
            find.byKey(const ValueKey('app-navigation-bar')),
            findsOneWidget,
          );
          expect(
            find.byType(
              screen.showsDetail ? ResourceDetailPane : ResourceListPane,
            ),
            findsOneWidget,
          );
          expect(
            find.byType(
              screen.showsDetail ? ResourceListPane : ResourceDetailPane,
            ),
            findsNothing,
          );
        }
        final bytes = await captureRt2w7Png(tester, key);
        final header = ByteData.sublistView(bytes);
        expect(header.getUint32(16), screen.viewport.width.toInt());
        expect(header.getUint32(20), screen.viewport.height.toInt());
        await tester.runAsync(() async {
          await directory.create(recursive: true);
          await File(
            '${directory.path}/${screen.captureName}.png',
          ).writeAsBytes(bytes, flush: true);
        });
        manifest.add({
          'name': screen.captureName,
          'width': screen.viewport.width.toInt(),
          'height': screen.viewport.height.toInt(),
          'pixelRatio': 1,
        });
      }
      await tester.runAsync(() async {
        await File('${directory.path}/rt2w7-captures.json').writeAsString(
          const JsonEncoder.withIndent(
            '  ',
          ).convert({'reference': rt2w7CaptureNotes, 'captures': manifest}),
          flush: true,
        );
      });
    },
  );
}
