import '../core/config/supabase_config.dart';
import '../models/models.dart';

class OnboardingInvitationService {
  const OnboardingInvitationService();

  static const _selection =
      'id, tenant_id, token, status, expires_at, created_at, completed_at';

  /// Creates a new pending invitation for the given [tenantId].
  Future<OnboardingInvitation> createInvitation(String tenantId) async {
    final row = await SupabaseConfig.client
        .from('tenant_onboarding_invitations')
        .insert({'tenant_id': tenantId})
        .select(_selection)
        .single();
    return OnboardingInvitation.fromRow(row);
  }

  /// Lists all invitations.  Staff only — enforced by RLS.
  /// Pass [tenantId] to filter to a specific tenant.
  Future<List<OnboardingInvitation>> listInvitations({
    String? tenantId,
  }) async {
    final rows = tenantId == null
        ? await SupabaseConfig.client
            .from('tenant_onboarding_invitations')
            .select(_selection)
            .order('created_at', ascending: false)
        : await SupabaseConfig.client
            .from('tenant_onboarding_invitations')
            .select(_selection)
            .eq('tenant_id', tenantId)
            .order('created_at', ascending: false);
    return rows.map(OnboardingInvitation.fromRow).toList();
  }

  /// Marks a pending invitation as revoked.  Staff only.
  Future<void> revokeInvitation(String invitationId) async {
    final count = await SupabaseConfig.client
        .from('tenant_onboarding_invitations')
        .update({'status': 'revoked'})
        .eq('id', invitationId)
        .eq('status', 'pending')
        .select('id');
    if ((count as List).isEmpty) {
      throw Exception(
        'Invitation could not be revoked. It may have already been used or expired.',
      );
    }
  }

  /// Called by the tenant after scanning the QR code. Validates ownership,
  /// status, and expiry server-side. Returns the invitation row.
  Future<OnboardingInvitation> claimInvitation(String token) async {
    final row = await SupabaseConfig.client
        .rpc('claim_onboarding_invitation', params: {'p_token': token});
    return OnboardingInvitation.fromRow(Map<String, dynamic>.from(row as Map));
  }

  /// Called when the tenant submits the onboarding form. Saves their data and
  /// marks the invitation completed.
  Future<OnboardingInvitation> completeInvitation({
    required String token,
    String schoolName = '',
    String courseOrProgram = '',
    int? yearLevel,
    String emergencyContactName = '',
    String emergencyContactPhone = '',
    String emergencyContactRelationship = '',
  }) async {
    final row = await SupabaseConfig.client
        .rpc('complete_onboarding_invitation', params: {
      'p_token': token,
      'p_school_name': schoolName.trim(),
      'p_course_or_program': courseOrProgram.trim(),
      'p_year_level': yearLevel,
      'p_emergency_contact_name': emergencyContactName.trim(),
      'p_emergency_contact_phone': emergencyContactPhone.trim(),
      'p_emergency_contact_relationship': emergencyContactRelationship.trim(),
    });
    return OnboardingInvitation.fromRow(Map<String, dynamic>.from(row as Map));
  }
}
