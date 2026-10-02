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
