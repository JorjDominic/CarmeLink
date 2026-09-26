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

  /// Returns the current tenant's active pending invitation, if any.
  Future<OnboardingInvitation?> getMyActiveInvitation() async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await SupabaseConfig.client
        .from('tenant_onboarding_invitations')
        .select(_selection)
        .eq('tenant_id', uid)
        .eq('status', 'pending')
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return OnboardingInvitation.fromRow(
      Map<String, dynamic>.from(list.first as Map),
    );
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

  /// Returns the tenant's details row. Defaults to the signed-in tenant.
  Future<Map<String, dynamic>?> getMyTenantDetails([String? targetTenantId]) async {
    final uid = targetTenantId ?? SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await SupabaseConfig.client
        .from('tenant_details')
        .select(
            'profile_id, school_name, course_or_program, year_level, emergency_contact_name, emergency_contact_phone, emergency_contact_relationship')
        .eq('profile_id', uid)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  /// Saves or updates onboarding details for the current tenant or [targetTenantId] (for staff).
  /// Automatically fulfills pending invitations if any exist.
  Future<void> submitTenantDetailsDirectly({
    String? targetTenantId,
    String? token,
    String schoolName = '',
    String courseOrProgram = '',
    int? yearLevel,
    String emergencyContactName = '',
    String emergencyContactPhone = '',
    String emergencyContactRelationship = '',
  }) async {
    final uid = targetTenantId ?? SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) throw Exception('User not signed in');

    // 1. If an invitation token is provided or active, try completing via RPC
    String? effectiveToken = token;
    if (effectiveToken == null && targetTenantId == null) {
      final active = await getMyActiveInvitation();
      effectiveToken = active?.token;
    }

    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      try {
        await completeInvitation(
          token: effectiveToken,
          schoolName: schoolName,
          courseOrProgram: courseOrProgram,
          yearLevel: yearLevel,
          emergencyContactName: emergencyContactName,
          emergencyContactPhone: emergencyContactPhone,
          emergencyContactRelationship: emergencyContactRelationship,
        );
        return;
      } catch (_) {
        // Fall back to direct submission
      }
    }

    // 2. Try the submit_tenant_onboarding_details RPC
    if (targetTenantId == null) {
      try {
        await SupabaseConfig.client.rpc(
          'submit_tenant_onboarding_details',
          params: {
            'p_school_name': schoolName.trim(),
            'p_course_or_program': courseOrProgram.trim(),
            'p_year_level': yearLevel,
            'p_emergency_contact_name': emergencyContactName.trim(),
            'p_emergency_contact_phone': emergencyContactPhone.trim(),
            'p_emergency_contact_relationship':
                emergencyContactRelationship.trim(),
          },
        );
        return;
      } catch (_) {
        // Fall back to direct update
      }
    }

    // 3. Fallback: direct table update
    await SupabaseConfig.client.from('tenant_details').update({
      'school_name': schoolName.trim().isEmpty ? null : schoolName.trim(),
      'course_or_program':
          courseOrProgram.trim().isEmpty ? null : courseOrProgram.trim(),
      'year_level': yearLevel,
      'emergency_contact_name':
          emergencyContactName.trim().isEmpty ? null : emergencyContactName.trim(),
      'emergency_contact_phone': emergencyContactPhone.trim().isEmpty
          ? null
          : emergencyContactPhone.trim(),
      'emergency_contact_relationship': emergencyContactRelationship.trim().isEmpty
          ? null
          : emergencyContactRelationship.trim(),
    }).eq('profile_id', uid);

    // Also mark any pending invitations as completed
    try {
      await SupabaseConfig.client
          .from('tenant_onboarding_invitations')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('tenant_id', uid)
          .eq('status', 'pending');
    } catch (_) {}
  }
}
