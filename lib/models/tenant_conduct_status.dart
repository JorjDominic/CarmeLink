class TenantConductStatus {
  const TenantConductStatus(
      this.tenantId, this.status, this.confirmed, this.recentConfirmed);

  factory TenantConductStatus.fromJson(Map<String, dynamic> json) =>
      TenantConductStatus(
          json['tenant_id'] as String,
          json['status'] as String,
          (json['confirmed'] as num).toInt(),
          (json['recent_confirmed'] as num).toInt());

  final String tenantId;
  final String status;
  final int confirmed;
  final int recentConfirmed;
  bool get needsReview =>
      status == 'repeated_violations' || status == 'continuous_violations';
  String get label => switch (status) {
        'continuous_violations' => 'Continuous violations',
        'repeated_violations' => 'Repeated violations',
        'single_confirmed' => 'One confirmed incident',
        _ => 'No confirmed violations',
      };
}
