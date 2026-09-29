import 'package:carmelitas_dormitory_system/services/web_workspace_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores last visible staff page and expanded sidebar groups',
      () async {
    SharedPreferences.setMockInitialValues({});
    const service = WebWorkspacePersistenceService();

    await service.saveDestination(
      roleLabel: 'Owner',
      baseDestinationLabel: 'Billing & charges',
      visiblePageLabel: 'Billing & charges',
    );
    await service.saveExpandedGroups(
      roleLabel: 'Owner',
      groups: {'Facilities', 'Billing & Records'},
    );

    final state = await service.load('Owner');
    expect(state.baseDestinationLabel, 'Billing & charges');
    expect(state.visiblePageLabel, 'Billing & charges');
    expect(
        state.expandedGroups, containsAll({'Facilities', 'Billing & Records'}));
  });

  test('owner and caretaker workspace state stay isolated', () async {
    SharedPreferences.setMockInitialValues({});
    const service = WebWorkspacePersistenceService();

    await service.saveDestination(
      roleLabel: 'Owner',
      baseDestinationLabel: 'Residents',
      visiblePageLabel: 'Residents',
    );
    await service.saveDestination(
      roleLabel: 'Caretaker',
      baseDestinationLabel: 'Maintenance',
      visiblePageLabel: 'Maintenance',
    );

    expect((await service.load('Owner')).visiblePageLabel, 'Residents');
    expect((await service.load('Caretaker')).visiblePageLabel, 'Maintenance');
  });
}
