import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/contract_onboarding_service.dart';
import '../services/onboarding_invitation_service.dart';

enum TenantAccessState { loading, restricted, approved, error }

class TenantOnboardingStatus {
  const TenantOnboardingStatus({
    required this.profileComplete,
    required this.hasPendingInvitation,
    required this.contract,
    required this.requirements,
    required this.signers,
  });

  final bool profileComplete;
  final bool hasPendingInvitation;
  final TenantContract? contract;
  final List<ContractRequirement> requirements;
  final List<ContractSigner> signers;

  List<ContractRequirement> get requiredRequirements =>
      requirements.where((item) => item.isRequired).toList(growable: false);

  List<ContractSigner> get requiredSigners =>
      signers.where((item) => item.isRequired).toList(growable: false);

  bool get documentsVerified =>
      requiredRequirements.isNotEmpty &&
      requiredRequirements.every((item) => item.isVerified);

  bool get signaturesVerified =>
      requiredSigners.isNotEmpty &&
      requiredSigners.every((item) => item.isVerified);

  bool get contractActive => contract?.isActive ?? false;

  bool get isApproved =>
      profileComplete &&
      !hasPendingInvitation &&
      contractActive &&
      documentsVerified &&
      signaturesVerified;

  int get completedSteps => [
        profileComplete && !hasPendingInvitation,
        documentsVerified,
        signaturesVerified,
        contractActive,
      ].where((complete) => complete).length;
}

/// Single source of truth for whether the tenant may enter the operational UI.
/// It deliberately fails closed when the status cannot be confirmed.
class TenantAccessController extends ChangeNotifier {
  TenantAccessController._();

  static final TenantAccessController instance = TenantAccessController._();

  final _profileService = const OnboardingInvitationService();
  final _contractService = const ContractOnboardingService();

  TenantAccessState _state = TenantAccessState.loading;
  TenantOnboardingStatus? _status;
  String? _error;
  int _requestGeneration = 0;

  TenantAccessState get state => _state;
  TenantOnboardingStatus? get status => _status;
  String? get error => _error;
  bool get canAccessCore => _state == TenantAccessState.approved;

  Future<void> refresh() async {
    final generation = ++_requestGeneration;
    // Keep the confirmed tenant workspace mounted during revalidation.
    // A failed or restricted result still revokes access below.
    if (_state != TenantAccessState.approved) {
      _state = TenantAccessState.loading;
    }
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object?>([
        _profileService.getMyTenantDetails(),
        _profileService.getMyActiveInvitation(),
        _contractService.getMyContract(),
      ]);
      final details = results[0] as Map<String, dynamic>?;
      final invitation = results[1] as OnboardingInvitation?;
      final contract = results[2] as TenantContract?;

      var requirements = <ContractRequirement>[];
      var signers = <ContractSigner>[];
      if (contract != null) {
        final contractResults = await Future.wait<Object>([
          _contractService.listRequirements(contract.id),
          _contractService.listSigners(contract.id),
        ]);
        requirements = contractResults[0] as List<ContractRequirement>;
        signers = contractResults[1] as List<ContractSigner>;
      }

      if (generation != _requestGeneration) return;
      final status = TenantOnboardingStatus(
        profileComplete: _hasCompleteEmergencyContact(details),
        hasPendingInvitation: invitation != null,
        contract: contract,
        requirements: requirements,
        signers: signers,
      );
      _status = status;
      _state = status.isApproved
          ? TenantAccessState.approved
          : TenantAccessState.restricted;
    } catch (error) {
      if (generation != _requestGeneration) return;
      _status = null;
      _state = TenantAccessState.error;
      _error = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  bool _hasCompleteEmergencyContact(Map<String, dynamic>? details) {
    final name = details?['emergency_contact_name']?.toString().trim() ?? '';
    final phone = details?['emergency_contact_phone']?.toString().trim() ?? '';
    final relationship =
        details?['emergency_contact_relationship']?.toString().trim() ?? '';
    return name.length >= 2 && phone.length >= 7 && relationship.length >= 2;
  }

  void clear() {
    _requestGeneration++;
    _state = TenantAccessState.loading;
    _status = null;
    _error = null;
    notifyListeners();
  }
}
