import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_manager/app/app_controller.dart';
import 'package:pve_manager/app/pve_manager_app.dart';
import 'package:pve_manager/features/connections/domain/connection_profile.dart';
import 'package:pve_manager/features/connections/data/connection_store.dart';
import 'package:pve_manager/presentation/presentation.dart';

void main() {
  for (final viewport in [const Size(390, 843), const Size(720, 1280)]) {
    testWidgets(
      'Android back returns from detail to list at ${viewport.width.toInt()}dp',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = _NavigationController()..selectResource(_resource);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: const PveManagerApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ResourceDetailPane), findsOneWidget);
        expect(find.byType(ResourceListPane), findsNothing);
        expect(find.text('PVE 管家'), findsNothing);
        expect(
          find.byKey(const ValueKey('app-navigation-bar')),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(controller.selectedResourceId, isNull);
        expect(find.byType(ResourceListPane), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _resource = ResourceViewModel(
  id: 'lab/qemu/101',
  connectionId: 'lab',
  connectionName: '家庭实验室',
  nodeName: 'pve-01',
  guestId: '101',
  name: 'Ubuntu Server',
  kind: ResourceKind.qemu,
  status: ResourceStatus.running,
);

class _NavigationController extends AppController {
  _NavigationController()
    : super(
        store: ConnectionStore(
          metadataStore: _Metadata(),
          secretStore: _Secrets(),
        ),
      );
  final _profile = ConnectionProfile(
    id: 'lab',
    name: '家庭实验室',
    host: 'pve.example.test',
    port: 8006,
    username: 'mobile',
    realm: 'pve',
    rememberPassword: false,
  );

  @override
  bool get isInitializing => false;

  @override
  List<ConnectionProfile> get profiles => [_profile];

  @override
  List<ResourceViewModel> get resourceViewModels => const [_resource];

  @override
  PaneStateViewModel get resourcesPaneState => const PaneStateViewModel();

  @override
  Future<void> refreshAll({bool showSpinner = true}) async {}
}

class _Metadata implements ProfileMetadataStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _Secrets implements SecretStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}
