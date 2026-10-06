class StaffTenantOption {
  const StaffTenantOption({
    required this.id,
    required this.name,
    required this.residencyStatus,
    this.room = 'Unassigned',
    this.floor = '',
    this.bed = 'No bed',
  });

  final String id;
  final String name;
  final String residencyStatus;
  final String room;
  final String floor;
  final String bed;

  bool get isActiveResident => residencyStatus != 'inactive';
  bool get isAssigned => room.isNotEmpty && room != 'Unassigned';

  String get locationLabel {
    if (!isAssigned) return 'Unassigned';
    final parts = <String>['Room $room'];
    if (bed.isNotEmpty && bed != 'No bed') parts.add(bed);
    if (floor.trim().isNotEmpty) parts.add(floor.trim());
    return parts.join(' • ');
  }
}
