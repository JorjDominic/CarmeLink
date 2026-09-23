import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingInvitation', () {
    test('parses a pending invitation and builds its opaque deep link', () {
      final invitation = OnboardingInvitation.fromRow({
        'id': 'invitation-1',
        'tenant_id': 'tenant-1',
        'token': 'opaque-token',
        'status': 'pending',
        'expires_at': DateTime.now()
            .add(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'completed_at': null,
      });

      expect(invitation.isPending, isTrue);
      expect(invitation.isUsable, isTrue);
      expect(
        invitation.deepLink,
        'carmelink://onboarding?token=opaque-token',
      );
    });

    test('treats a past pending invitation as expired and unusable', () {
      final invitation = OnboardingInvitation.fromRow({
        'id': 'invitation-2',
        'tenant_id': 'tenant-1',
        'token': 'expired-token',
        'status': 'pending',
        'expires_at': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toUtc()
            .toIso8601String(),
        'created_at': DateTime.now()
            .subtract(const Duration(days: 8))
            .toUtc()
            .toIso8601String(),
        'completed_at': null,
      });

      expect(invitation.isExpired, isTrue);
      expect(invitation.isUsable, isFalse);
    });

    test('parses completed timestamp and completed status', () {
      final completedAt = DateTime.now().toUtc();
      final invitation = OnboardingInvitation.fromRow({
        'id': 'invitation-3',
        'tenant_id': 'tenant-1',
        'token': 'used-token',
        'status': 'completed',
        'expires_at':
            completedAt.add(const Duration(days: 5)).toIso8601String(),
        'created_at':
            completedAt.subtract(const Duration(hours: 1)).toIso8601String(),
        'completed_at': completedAt.toIso8601String(),
      });

      expect(invitation.isCompleted, isTrue);
      expect(invitation.isUsable, isFalse);
      expect(invitation.completedAt, isNotNull);
    });
  });
}
