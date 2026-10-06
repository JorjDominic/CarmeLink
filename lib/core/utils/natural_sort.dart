int compareNaturalLabels(String left, String right) {
  final tokenPattern = RegExp(r'\d+|\D+');
  final leftTokens = tokenPattern
      .allMatches(left.toLowerCase())
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final rightTokens = tokenPattern
      .allMatches(right.toLowerCase())
      .map((match) => match.group(0)!)
      .toList(growable: false);

  final sharedLength = leftTokens.length < rightTokens.length
      ? leftTokens.length
      : rightTokens.length;

  for (var index = 0; index < sharedLength; index++) {
    final leftToken = leftTokens[index];
    final rightToken = rightTokens[index];
    final leftNumber = int.tryParse(leftToken);
    final rightNumber = int.tryParse(rightToken);

    final comparison = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : leftToken.compareTo(rightToken);

    if (comparison != 0) return comparison;
  }

  return leftTokens.length.compareTo(rightTokens.length);
}

/// Sorts common dormitory floor labels in building order while still
/// supporting owner-defined labels such as "Floor 3", "3rd floor", or
/// "Annex 2".
int compareFloorLabels(String left, String right) {
  final leftRank = _floorRank(left);
  final rightRank = _floorRank(right);

  if (leftRank != null && rightRank != null && leftRank != rightRank) {
    return leftRank.compareTo(rightRank);
  }
  if (leftRank != null && rightRank == null) return -1;
  if (leftRank == null && rightRank != null) return 1;
  return compareNaturalLabels(left, right);
}

int? _floorRank(String label) {
  final normalized = label.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  if (normalized.contains('basement')) return -1;
  if (normalized.contains('ground')) return 0;

  final number = RegExp(r'\d+').firstMatch(normalized);
  if (number != null) return int.tryParse(number.group(0)!);

  const words = <String, int>{
    'first': 1,
    'second': 2,
    'third': 3,
    'fourth': 4,
    'fifth': 5,
    'sixth': 6,
    'seventh': 7,
    'eighth': 8,
    'ninth': 9,
    'tenth': 10,
  };
  for (final entry in words.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  return null;
}
