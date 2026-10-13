import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pve_manager/app/app_info.dart';
import 'package:pve_manager/presentation/nodes/node_detail_pane.dart';
import 'package:pve_manager/presentation/resources/resource_detail_pane.dart';

import '../test/support/promo_video_app.dart';
import '../test/support/rt2w7_acceptance.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'records offline promotional walkthrough',
    (tester) async {
      await tester.runAsync(loadRt2w7Fonts);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFFF5F7FB),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      final key = GlobalKey<PromoVideoAppState>();
      await tester.pumpWidget(PromoVideoApp(key: key));
      await tester.pumpAndSettle();
      final cues = <Map<String, Object>>[];
      final clock = Stopwatch()..start();
      void cue(String id, String description) {
        cues.add({
          'id': id,
          'description': description,
          'milliseconds': clock.elapsedMilliseconds,
          'utc': DateTime.now().toUtc().toIso8601String(),
        });
        debugPrint('PROMO_CUE=$id');
      }

      Future<void> hold(double seconds) async {
        await tester.pump(Duration(milliseconds: (seconds * 1000).round()));
        expect(tester.takeException(), isNull);
      }

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> swipe(Finder finder, double distance) async {
        await tester.timedDrag(
          finder,
          Offset(0, distance),
          const Duration(milliseconds: 1100),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Finder navigation(String label) => find.descendant(
        of: find.byKey(const ValueKey('app-navigation-bar')),
        matching: find.text(label),
      );
      cue('ready', '首页预录缓冲');
      await hold(8);
      cue('home', '应用内版本与资源总览');
      await hold(3);
      await tap(find.text('虚拟机'));
      cue('vm_filter', '虚拟机筛选');
      await hold(2);
      await tap(find.text('容器'));
      cue('ct_filter', '容器筛选');
      await hold(2);
      await tap(find.text('全部'));
      await hold(.5);
      await tap(find.text('Ubuntu Server'));
      cue('resource', '虚拟机详情与CPU内存');
      await hold(3);
      await swipe(
        find.descendant(
          of: find.byType(ResourceDetailPane),
          matching: find.byType(SingleChildScrollView),
        ),
        -270,
      );
      cue('power', '电源与控制台操作区域（只展示）');
      await hold(2);
      await tap(find.text('重启'));
      cue('confirmation', '真实产品确认弹窗，演示中取消');
      await hold(2);
      await tap(find.text('取消'));
      await swipe(
        find.descendant(
          of: find.byType(ResourceDetailPane),
          matching: find.byType(SingleChildScrollView),
        ),
        320,
      );
      await tap(find.byTooltip('返回资源列表'));
      await tap(navigation('节点'));
      cue('nodes', '节点资源列表');
      await hold(2);
      await tap(find.text('pve-01'));
      cue('overview', 'CPU 内存 根分区 网络资源概览');
      await hold(4);
      final nodeScroll = find.descendant(
        of: find.byType(NodeDetailPane),
        matching: find.byType(SingleChildScrollView),
      );
      await swipe(nodeScroll, -470);
      cue('history', 'CPU与内存历史曲线');
      await hold(3);
      await tap(find.byKey(const ValueKey('monitoring-timeframe-day')));
      cue('day', '切换一天时间范围，离线模拟采样');
      await hold(2);
      await swipe(nodeScroll, -380);
      cue('network', '网络与根分区趋势');
      await hold(3);
      await swipe(nodeScroll, -430);
      cue('storage', '节点存储 local / local-lvm');
      await hold(3);
      await tap(navigation('连接'));
      cue('connections', '多服务器连接管理');
      await hold(2);
      await tap(find.text('新增连接'));
      cue('login', 'R5YnD登录页面与证书提示');
      await hold(3);
      await tap(find.byKey(const ValueKey('connection-advanced-toggle')));
      await hold(.5);
      await swipe(find.byType(SingleChildScrollView), -240);
      cue('advanced', '高级设置：端口8006，认证域pam');
      await hold(4);
      key.currentState!.home();
      await tester.pumpAndSettle();
      cue('end_home', '回到资源总览');
      await hold(3);
      cue('end', '录制结束');
      binding.reportData = {
        'offline': true,
        'version': '${AppInfo.version}+${AppInfo.buildNumber}',
        'cues': cues,
        'durationMilliseconds': clock.elapsedMilliseconds,
      };
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
