import 'moon.dart';

/// One month definition: name + length in days (the *base* length, before
/// any leap-rule additions are applied).
class MonthDef {
  const MonthDef({required this.name, required this.days})
      : assert(days > 0, 'month length must be positive');

  final String name;
  final int days;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthDef && other.name == name && other.days == days;

  @override
  int get hashCode => Object.hash(name, days);
}

/// Optional "every N years, add 1 day to month X" leap rule. Modeled as a
/// single insertion to keep MVP scope. Gregorian-style nested exceptions
/// and inserted-month variants are explicitly out of scope (see CONTEXT.md).
class LeapRule {
  const LeapRule({
    required this.everyNYears,
    required this.extraDayInMonthIndex,
  })  : assert(everyNYears > 0, 'everyNYears must be positive'),
        assert(extraDayInMonthIndex >= 0, 'monthIndex must be non-negative');

  final int everyNYears;
  final int extraDayInMonthIndex;

  bool isLeapYear(int year) => year % everyNYears == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeapRule &&
          other.everyNYears == everyNYears &&
          other.extraDayInMonthIndex == extraDayInMonthIndex;

  @override
  int get hashCode => Object.hash(everyNYears, extraDayInMonthIndex);
}

/// Per-world calendar configuration. The engine treats `(startYear, 0, 1)`
/// as the epoch reference — i.e. day 0 of `daysSinceEpoch`.
class CalendarConfig {
  const CalendarConfig({
    required this.daysPerWeek,
    required this.weekdayNames,
    required this.months,
    required this.epochName,
    required this.startYear,
    this.leapRule,
    this.moons = const [],
  }) : assert(daysPerWeek > 0, 'daysPerWeek must be positive');
  // List-length asserts can't be const-evaluated, so callers are responsible
  // for ensuring `months` and `weekdayNames` are non-empty.

  final int daysPerWeek;
  final List<String> weekdayNames;
  final List<MonthDef> months;
  final String epochName;
  final int startYear;
  final LeapRule? leapRule;
  final List<MoonDef> moons;

  /// Length of the given month in the given year, honoring the leap rule.
  int daysInMonth(int year, int monthIndex) {
    final base = months[monthIndex].days;
    if (leapRule != null &&
        monthIndex == leapRule!.extraDayInMonthIndex &&
        leapRule!.isLeapYear(year)) {
      return base + 1;
    }
    return base;
  }

  /// Total days in the given year, honoring the leap rule.
  int daysInYear(int year) {
    var total = 0;
    for (var i = 0; i < months.length; i++) {
      total += daysInMonth(year, i);
    }
    return total;
  }

  bool isValidDate(int year, int monthIndex, int day) {
    if (monthIndex < 0 || monthIndex >= months.length) return false;
    if (day < 1 || day > daysInMonth(year, monthIndex)) return false;
    return true;
  }
}
