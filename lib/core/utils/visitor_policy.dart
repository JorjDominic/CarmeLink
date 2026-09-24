class VisitorPolicy {
  const VisitorPolicy._();

  static const int openingHour = 9;
  static const int closingHour = 21;

  static const String visitingHoursLabel = '9:00 AM–9:00 PM';
  static const String advanceRegistrationLabel =
      'Submit at least one calendar day before the visit.';

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime minimumVisitDate({DateTime? now}) =>
      dateOnly(now ?? DateTime.now()).add(const Duration(days: 1));

  static DateTime defaultArrival({DateTime? now}) {
    final day = minimumVisitDate(now: now);
    return DateTime(day.year, day.month, day.day, 10);
  }

  static DateTime defaultDeparture(DateTime arrival) {
    final suggested = arrival.add(const Duration(hours: 2));
    final closing =
        DateTime(arrival.year, arrival.month, arrival.day, closingHour);

    if (suggested.isAfter(closing)) return closing;
    return suggested;
  }

  static int _minutesOfDay(DateTime value) => value.hour * 60 + value.minute;

  static bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String? validateArrival(
    DateTime arrival, {
    DateTime? now,
  }) {
    final minimumDate = minimumVisitDate(now: now);
    if (dateOnly(arrival).isBefore(minimumDate)) {
      return 'Visitor requests must be submitted at least one calendar day before the visit.';
    }

    final minutes = _minutesOfDay(arrival);
    final opening = openingHour * 60;
    final closing = closingHour * 60;

    if (minutes < opening || minutes >= closing) {
      return 'Expected arrival must be between 9:00 AM and before 9:00 PM.';
    }

    return null;
  }

  static String? validateDeparture(
    DateTime arrival,
    DateTime departure,
  ) {
    if (!_sameCalendarDay(arrival, departure)) {
      return 'Visitors must depart on the same day. Overnight stays are not permitted.';
    }

    if (!departure.isAfter(arrival)) {
      return 'Expected departure must be after the expected arrival.';
    }

    final departureMinutes = _minutesOfDay(departure);
    final closing = closingHour * 60;

    if (departureMinutes > closing) {
      return 'Expected departure must be no later than 9:00 PM.';
    }

    return null;
  }

  static String? validateVisit({
    required DateTime schedule,
    required DateTime expectedDepartureAt,
    DateTime? now,
  }) {
    final arrivalIssue = validateArrival(schedule, now: now);
    if (arrivalIssue != null) return arrivalIssue;

    return validateDeparture(schedule, expectedDepartureAt);
  }
}
