import 'package:flutter/material.dart';

/// Service managing the independent guardian personal alert notification preference.
///
/// This alert path is strictly guardian-facing:
/// - It does NOT write to gate_events
/// - It does NOT modify current_gate_status
/// - It does NOT trigger official curfew disciplinary escalation
class GuardianAlertService {
  const GuardianAlertService();

  static TimeOfDay _preferredAlertTime = const TimeOfDay(hour: 21, minute: 0); // 9:00 PM default

  static TimeOfDay get preferredAlertTime => _preferredAlertTime;

  static void setPreferredAlertTime(TimeOfDay time) {
    _preferredAlertTime = time;
  }

  /// Determines if an informational alert should be sent to the guardian.
  ///
  /// Evaluates true if:
  /// 1. The current time is at or after the guardian's chosen alert time (e.g. 9:00 PM).
  /// 2. The linked tenant's most recent status is 'OUT' / 'Outside'.
  static bool shouldTriggerGuardianAlert({
    required String? linkedTenantGateStatus,
    TimeOfDay? alertTime,
    DateTime? now,
  }) {
    final targetTime = alertTime ?? _preferredAlertTime;
    final currentTime = now ?? DateTime.now();

    final alertDateTime = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      targetTime.hour,
      targetTime.minute,
    );

    // If current time has not reached the guardian's chosen alert cutoff for today
    if (currentTime.isBefore(alertDateTime)) {
      return false;
    }

    final isOutside = linkedTenantGateStatus == 'OUT' ||
        linkedTenantGateStatus == 'Outside';

    return isOutside;
  }
}

