import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pve_manager/app/pve_manager_app.dart';
import 'package:pve_manager/features/console/data/console_cookie_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first-run connection workflow renders on Android', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PveManagerApp()));
    await tester.pumpAndSettle();

    expect(find.text('登录 PVE'), findsOneWidget);
    expect(find.byKey(const ValueKey('connection-host-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('connection-password-field')),
      findsOneWidget,
    );
  });

  testWidgets('native WebView auth cookie can be set and cleared', (
    tester,
  ) async {
    final origin = Uri.parse('https://pve.integration.test:8006');
    await ConsoleCookieBridge.setSecureCookie(
      origin: origin,
      ticket: 'PVE:integration-test:ticket',
    );
    await ConsoleCookieBridge.clearAuthCookie(origin: origin);
  });
}
