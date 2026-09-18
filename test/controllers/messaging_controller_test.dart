import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/messaging_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessagingController', () {
    final controller = MessagingController.instance;

    setUp(() {
      controller.clear();
    });

    test('initial state is clean', () {
      expect(controller.activeConversation, isNull);
      expect(controller.activeMessages, isEmpty);
      expect(controller.conversations, isEmpty);
      expect(controller.selectedFilter, 'all');
      expect(controller.searchQuery, '');
    });

    test('mock tenant messages load properly', () async {
      await controller.loadTenantConversation('non-existent-tenant-id');

      expect(controller.activeConversation, isNotNull);
      expect(controller.activeConversation?.title, 'Dormitory Management');
      expect(controller.activeMessages, isNotEmpty);
    });

    test('sendMessage appends new message and updates state', () async {
      await controller.loadTenantConversation('non-existent-tenant-id');
      final initialCount = controller.activeMessages.length;

      final success = await controller.sendMessage('Hello this is a test message');
      expect(success, isTrue);
      expect(controller.activeMessages.length, initialCount + 1);
      expect(controller.activeMessages.last.body, 'Hello this is a test message');
    });

    test('filter and search works on conversation list', () async {
      await controller.loadConversations(force: true);

      expect(controller.conversations, isNotEmpty);

      // Filter by tenant
      controller.setFilter('tenant');
      expect(controller.filteredConversations.every((c) => c.isTenantManagement), isTrue);

      // Filter by guardian
      controller.setFilter('guardian');
      expect(controller.filteredConversations.every((c) => c.isGuardianManagement), isTrue);

      // Search by name
      controller.setFilter('all');
      controller.setSearchQuery('Anna');
      for (final conv in controller.filteredConversations) {
        final matches = conv.title.toLowerCase().contains('anna') ||
            conv.subtitle.toLowerCase().contains('anna') ||
            (conv.lastMessagePreview ?? '').toLowerCase().contains('anna');
        expect(matches, isTrue);
      }
    });

    test('closeActiveConversation resets active thread', () async {
      await controller.loadTenantConversation('test-tenant');
      expect(controller.activeConversation, isNotNull);

      controller.closeActiveConversation();
      expect(controller.activeConversation, isNull);
      expect(controller.activeMessages, isEmpty);
    });
  });
}

