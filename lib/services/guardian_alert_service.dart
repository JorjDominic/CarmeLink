import 'package:flutter/material.dart';

import '../core/config/supabase_config.dart';

/// Service managing the independent guardian personal alert notification preference.
///
/// This alert path is strictly guardian-facing:
/// - It does NOT write to gate_events
/// - It does NOT modify current_gate_status
/// - It does NOT trigger official curfew disciplinary escalation
class GuardianAlertService {
  const GuardianAlertService();

  static TimeOfDay _preferredAlertTime =
      const TimeOfDay(hour: 21, minute: 0); // 9:00 PM default
  static bool _gateEntryEnabled = true;
  static bool _gateExitEnabled = true;
  static bool _outsideAfterCutoffEnabled = true;
  static bool _insideAfterCutoffEnabled = false;

  static TimeOfDay get preferredAlertTime => _preferredAlertTime;
  static bool get gateEntryEnabled => _gateEntryEnabled;
  static bool get gateExitEnabled => _gateExitEnabled;
  static bool get outsideAfterCutoffEnabled => _outsideAfterCutoffEnabled;
  static bool get insideAfterCutoffEnabled => _insideAfterCutoffEnabled;

  @visibleForTesting
  static void setPreferredAlertTime(TimeOfDay time) {
    _preferredAlertTime = time;
  }

  @visibleForTesting
  static void setInsideAfterCutoffEnabled(bool enabled) {
    _insideAfterCutoffEnabled = enabled;
  }

  @visibleForTesting
  static void setOutsideAfterCutoffEnabled(bool enabled) {
    _outsideAfterCutoffEnabled = enabled;
  }

  static Future<void> load() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null || client.auth.currentUser == null) return;
    final value = await client.rpc('get_my_guardian_alert_preferences');
    final row = Map<String, dynamic>.from(value as Map);
    _gateEntryEnabled = row['gate_entry_enabled'] as bool? ?? true;
    _gateExitEnabled = row['gate_exit_enabled'] as bool? ?? true;
    _outsideAfterCutoffEnabled =
        row['outside_after_cutoff_enabled'] as bool? ?? true;
    _insideAfterCutoffEnabled =
        row['inside_after_cutoff_enabled'] as bool? ?? false;
    final parts = (row['alert_cutoff']?.toString() ?? '21:00').split(':');
    _preferredAlertTime = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 21,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  static Future<void> save({
    TimeOfDay? alertTime,
    bool? gateEntryEnabled,
    bool? gateExitEnabled,
    bool? outsideAfterCutoffEnabled,
    bool? insideAfterCutoffEnabled,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null || client.auth.currentUser == null) {
      throw Exception('Sign in as a guardian to save alert preferences.');
    }
    final nextTime = alertTime ?? _preferredAlertTime;
    final nextEntry = gateEntryEnabled ?? _gateEntryEnabled;
    final nextExit = gateExitEnabled ?? _gateExitEnabled;
    final nextCutoff = outsideAfterCutoffEnabled ?? _outsideAfterCutoffEnabled;
    final nextInside = insideAfterCutoffEnabled ?? _insideAfterCutoffEnabled;
    await client.rpc('update_my_guardian_alert_preferences', params: {
      'p_gate_entry_enabled': nextEntry,
      'p_gate_exit_enabled': nextExit,
      'p_outside_after_cutoff_enabled': nextCutoff,
      'p_inside_after_cutoff_enabled': nextInside,
      'p_alert_cutoff':
          '${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}:00',
    });
    _preferredAlertTime = nextTime;
    _gateEntryEnabled = nextEntry;
    _gateExitEnabled = nextExit;
    _outsideAfterCutoffEnabled = nextCutoff;
    _insideAfterCutoffEnabled = nextInside;
  }

  static String alertSummary(BuildContext context) {
    final timeStr = _preferredAlertTime.format(context);
    if (_outsideAfterCutoffEnabled && _insideAfterCutoffEnabled) {
      return 'Alert me if resident is outside or inside past $timeStr';
    } else if (_insideAfterCutoffEnabled) {
      return 'Alert me if resident is inside past $timeStr';
    } else if (_outsideAfterCutoffEnabled) {
      return 'Alert me if resident is outside past $timeStr';
    }
    return 'Alert preferences disabled';
  }

  /// Determines if an informational alert should be sent to the guardian.
  ///
  /// Evaluates true if:
  /// 1. The current time is at or after the guardian's chosen alert time (e.g. 9:00 PM).
  /// 2. If checkInside is false: linked tenant status is 'OUT' / 'Outside'.
  /// 3. If checkInside is true: linked tenant status is 'IN' / 'Inside'.
  static bool shouldTriggerGuardianAlert({
    required String? linkedTenantGateStatus,
    TimeOfDay? alertTime,
    DateTime? now,
    bool checkInside = false,
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

    if (checkInside) {
      return linkedTenantGateStatus == 'IN' ||
          linkedTenantGateStatus == 'Inside';
    }

    final isOutside =
        linkedTenantGateStatus == 'OUT' || linkedTenantGateStatus == 'Outside';

    return isOutside;
  }
}
