/// Parses financial input exactly, without floating-point allocation.
int parseRentCents(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException('Enter an amount with at most two decimals');
  }
  final parts = value.split('.');
  final cents = int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  if (cents > 999999999999) throw const FormatException('Amount is too large');
  return cents;
}

/// Stable tenant ID order allocates leftover centavos; no money is lost.
Map<String, int> allocateContractRent(int totalCents, List<String> tenantIds) {
  if (totalCents < 0 ||
      totalCents > 999999999999 ||
      tenantIds.isEmpty ||
      tenantIds.length > 4 ||
      tenantIds.toSet().length != tenantIds.length) {
    throw ArgumentError(
        'Select one to four unique tenants and a valid room rent');
  }
  final ids = [...tenantIds]..sort();
  return {
    for (var i = 0; i < ids.length; i++)
      ids[i]: totalCents ~/ ids.length + (i < totalCents % ids.length ? 1 : 0),
  };
}

String rentCentsText(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
