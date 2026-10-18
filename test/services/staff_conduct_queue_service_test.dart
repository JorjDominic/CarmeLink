import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/models/staff_tenant_option.dart';
import 'package:carmelitas_dormitory_system/models/tenant_conduct_status.dart';
import 'package:carmelitas_dormitory_system/services/conduct_case_service.dart';
import 'package:carmelitas_dormitory_system/services/staff_conduct_queue_service.dart';
import 'package:carmelitas_dormitory_system/services/staff_tenant_picker_service.dart';

class Tenants extends StaffTenantPickerService {
  bool fail = false;
  @override
  Future<List<StaffTenantOption>> listTenantOptions() async {
    if (fail) throw StateError('Tenant read failed');
    return const [
      StaffTenantOption(
          id: 'tenant-1', name: 'Active tenant', residencyStatus: 'active')
    ];
  }
}

class Cases extends ConductCaseService {
  bool trackingFails = true, casesFail = false;
  @override
  Future<List<ConductCaseRecord>> listStaffCases() async {
    if (casesFail) throw StateError('Case read failed');
    final date = DateTime.utc(2026, 10, 19);
    return [
      ConductCaseRecord(
          id: 'case-1',
          category: 'safety',
          title: 'Existing case',
          description: 'Existing case description',
          incidentAt: date,
          status: 'under_review',
          createdAt: date,
          updatedAt: date)
    ];
  }

  @override
  Future<Map<String, TenantConductStatus>> tenantStatuses() async {
    if (trackingFails)
      throw const PostgrestException(
          message: 'Could not find function list_conduct_tenant_statuses',
          code: 'PGRST202');
    return const {
      'tenant-1': TenantConductStatus('tenant-1', 'repeated_violations', 2, 1)
    };
  }
}

void main() {
  test(
      'missing repeat-status migration preserves active tenants and existing cases',
      () async {
    final result =
        await StaffConductQueueService(cases: Cases(), tenants: Tenants())
            .load();
    expect(result.tenants.single.isActiveResident, isTrue);
    expect(result.cases.single.id, 'case-1');
    expect(result.statuses, isNull);
  });
  test('tracking recovers on refresh after migration is available', () async {
    final cases = Cases();
    final service = StaffConductQueueService(cases: cases, tenants: Tenants());
    expect((await service.load()).statuses, isNull);
    cases.trackingFails = false;
    expect((await service.load()).statuses!['tenant-1']!.needsReview, isTrue);
  });
  test('required tenant and case read errors are not reported as empty lists',
      () async {
    await expectLater(
        StaffConductQueueService(
                cases: Cases(), tenants: Tenants()..fail = true)
            .load(),
        throwsStateError);
    await expectLater(
        StaffConductQueueService(
                cases: Cases()..casesFail = true, tenants: Tenants())
            .load(),
        throwsStateError);
  });
}
