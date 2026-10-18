import '../models/staff_tenant_option.dart';
import '../models/tenant_conduct_status.dart';
import 'conduct_case_service.dart';
import 'staff_tenant_picker_service.dart';

class StaffConductQueueSnapshot {
  const StaffConductQueueSnapshot(this.tenants, this.cases, this.statuses);
  final List<StaffTenantOption> tenants;
  final List<ConductCaseRecord> cases;

  /// Null means tracking could not be loaded, rather than zero incidents.
  final Map<String, TenantConductStatus>? statuses;
}

class StaffConductQueueService {
  const StaffConductQueueService({
    this.cases = const ConductCaseService(),
    this.tenants = const StaffTenantPickerService(),
  });
  final ConductCaseService cases;
  final StaffTenantPickerService tenants;

  Future<StaffConductQueueSnapshot> load() async {
    final options = await tenants.listTenantOptions();
    final records = await cases.listStaffCases();
    Map<String, TenantConductStatus>? statuses;
    try {
      statuses = await cases.tenantStatuses();
    } catch (_) {
      // Optional tracking may not be deployed yet. Required reads still throw.
    }
    return StaffConductQueueSnapshot(options, records, statuses);
  }
}
