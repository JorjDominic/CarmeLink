import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';

void main() {
  const tenants = [
    TenantDirectoryEntry(
      id: 'tenant-1',
      name: 'Alex Rivera',
      room: '101',
      bedSpace: 'Bed A',
      phone: '09123456789',
      guardianName: 'Maria Rivera',
      guardianPhone: '09999999999',
    ),
    TenantDirectoryEntry(
      id: 'tenant-2',
      name: 'Bella Santos',
      room: '202',
      bedSpace: 'Bed B',
      phone: '09120000000',
      guardianName: 'Jose Santos',
      guardianPhone: '09121111111',
      residencyStatus: 'moving_out',
    ),
    TenantDirectoryEntry(
      id: 'tenant-3',
      name: 'Carla Reyes',
      room: 'Unassigned',
      bedSpace: 'No bed',
      phone: '',
      guardianName: 'Not assigned',
      guardianPhone: '',
      residencyStatus: 'inactive',
    ),
  ];

  test(
      'search matches names, rooms, phones and guardians without case sensitivity',
      () {
    expect(
        filterTenantDirectory(tenants, query: ' ALEX ').single.id, 'tenant-1');
    expect(filterTenantDirectory(tenants, query: '202').single.id, 'tenant-2');
    expect(filterTenantDirectory(tenants, query: '09123456789').single.id,
        'tenant-1');
    expect(filterTenantDirectory(tenants, query: 'jOsE').single.id, 'tenant-2');
  });

  test('residency filters compose with search without modifying source entries',
      () {
    expect(filterTenantDirectory(tenants, residency: 'active').length, 1);
    expect(filterTenantDirectory(tenants, residency: 'moving_out').single.id,
        'tenant-2');
    expect(filterTenantDirectory(tenants, residency: 'inactive', query: 'Alex'),
        isEmpty);
    expect(tenants.length, 3);
  });

  test(
      'blank queries return all entries and missing searches return empty list',
      () {
    expect(filterTenantDirectory(tenants, query: '  ').length, 3);
    expect(filterTenantDirectory(tenants, query: 'not-a-tenant'), isEmpty);
  });
}
