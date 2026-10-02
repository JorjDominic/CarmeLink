import 'package:carmelitas_dormitory_system/core/utils/natural_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('natural label sorting keeps numeric room and bed order', () {
    final rooms = ['205', '10', '2', '1', 'Room 12', 'Room 3']
      ..sort(compareNaturalLabels);
    expect(rooms, ['1', '2', '10', '205', 'Room 3', 'Room 12']);

    final beds = ['Bed 10', 'Bed 2', 'Bed 1']..sort(compareNaturalLabels);
    expect(beds, ['Bed 1', 'Bed 2', 'Bed 10']);
  });
}
