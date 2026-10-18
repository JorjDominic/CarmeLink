import 'package:carmelitas_dormitory_system/services/confidentiality_agreement_service.dart';

/// Explicit accepted prerequisite for tests focused on module contents.
class AcceptedModuleAgreements extends ConfidentialityAgreementService {
  const AcceptedModuleAgreements();
  @override
  Future<ModuleAgreementStatus> status() async =>
      const ModuleAgreementStatus(allowed: true);
}
