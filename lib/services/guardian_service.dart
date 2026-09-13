import '../core/config/supabase_config.dart';
import '../models/models.dart';
import 'payment_service.dart';
import 'room_service.dart';

class GuardianService {
  const GuardianService();

  static List<LinkedTenant>? _cachedLinkedTenants;
  static DateTime? _lastFetch;

  static List<LinkedTenant>? get cachedLinkedTenants => _cachedLinkedTenants;

  static void invalidateCache() {
    _cachedLinkedTenants = null;
    _lastFetch = null;
  }

  /// Loads all tenants linked to the current logged-in guardian.
  Future<List<LinkedTenant>> loadLinkedTenants({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedLinkedTenants != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(seconds: 30)) {
      return _cachedLinkedTenants!;
    }

    final client = SupabaseConfig.clientSafe;
    if (client == null) return _fallbackList();

    final guardianId = client.auth.currentUser?.id;
    if (guardianId == null) return _fallbackList();

    try {
      // Fetch links with linked profile
      final linkRows = await client
          .from('guardian_tenant_links')
          .select(
            'id, tenant_id, relationship, is_primary, '
            'tenant:profiles!guardian_tenant_links_tenant_id_fkey(id, full_name, phone)',
          )
          .eq('guardian_id', guardianId)
          .order('is_primary', ascending: false);

      if (linkRows.isEmpty) {
        _cachedLinkedTenants = [];
        _lastFetch = DateTime.now();
        return [];
      }

      final tenantIds = linkRows
          .map((row) => row['tenant_id'] as String?)
          .whereType<String>()
          .toList();

      // Fetch tenant details for education & emergency contact
      final detailRows = await client
          .from('tenant_details')
          .select(
            'profile_id, school_name, course_or_program, year_level, '
            'emergency_contact_name, emergency_contact_phone, residency_status',
          )
          .filter('profile_id', 'in', tenantIds);

      final detailsMap = <String, Map<String, dynamic>>{
        for (final d in detailRows) d['profile_id'] as String: d,
      };

      final linkedList = linkRows.map((row) {
        final tId = row['tenant_id'] as String;
        final profile = row['tenant'] as Map<String, dynamic>?;
        final detail = detailsMap[tId];

        return LinkedTenant(
          linkId: row['id'] as String,
          tenantId: tId,
          name: profile?['full_name'] as String? ?? 'Resident',
          phone: profile?['phone'] as String? ?? '',
          relationship: row['relationship'] as String? ?? 'Guardian',
          isPrimary: row['is_primary'] as bool? ?? false,
          schoolName: detail?['school_name'] as String? ?? '',
          courseOrProgram: detail?['course_or_program'] as String? ?? '',
          yearLevel: (detail?['year_level'] as num?)?.toInt(),
          emergencyContactName:
              detail?['emergency_contact_name'] as String? ?? '',
          emergencyContactPhone:
              detail?['emergency_contact_phone'] as String? ?? '',
          residencyStatus: detail?['residency_status'] as String? ?? 'active',
        );
      }).toList();

      _cachedLinkedTenants = linkedList;
      _lastFetch = DateTime.now();
      return linkedList;
    } catch (_) {
      return _cachedLinkedTenants ?? _fallbackList();
    }
  }

  /// Loads the room details for a linked tenant.
  Future<Room?> loadTenantRoom(String tenantId) {
    const roomService = RoomService();
    return roomService.getMyRoomDetails(tenantId: tenantId);
  }

  /// Loads payments for a linked tenant.
  Future<List<Payment>> loadTenantPayments(String tenantId) {
    const paymentService = PaymentService();
    return paymentService.listPaymentsForTenant(tenantId);
  }

  List<LinkedTenant> _fallbackList() => const [];
}

