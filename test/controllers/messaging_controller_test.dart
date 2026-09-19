import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/messaging_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

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

    test('unauthenticated tenant load exposes an error without demo data',
        () async {
      await controller.loadTenantConversation('');
      expect(controller.activeConversation, isNull);
      expect(controller.activeMessages, isEmpty);
      expect(controller.messagesError, isNotNull);
    });

    test('filter and search works on conversation list', () async {
      controller.setConversationsForTesting([
        ConversationRecord(
          id: 'tenant-conversation',
          type: 'tenant_management',
          title: 'Anna Tenant',
          subtitle: 'Tenant',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
        ConversationRecord(
          id: 'guardian-conversation',
          type: 'guardian_management',
          title: 'Maria Guardian',
          subtitle: 'Guardian',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      ]);

      expect(controller.conversations, isNotEmpty);

      // Filter by tenant
      controller.setFilter('tenant');
      expect(
          controller.filteredConversations.every((c) => c.isTenantManagement),
          isTrue);

      // Filter by guardian
      controller.setFilter('guardian');
      expect(
          controller.filteredConversations.every((c) => c.isGuardianManagement),
          isTrue);

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
      controller.setConversationForTesting(
        ConversationRecord(
          id: 'conversation',
          type: 'tenant_management',
          title: 'Management',
          subtitle: 'Staff',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      );
      expect(controller.activeConversation, isNotNull);

      controller.closeActiveConversation();
      expect(controller.activeConversation, isNull);
      expect(controller.activeMessages, isEmpty);
    });
  });
}
