import 'calendar_config.dart';
import 'moon.dart';
import 'world_date.dart';

/// Days from `(config.startYear, 0, 1)` to `date`. Negative for dates earlier
/// than the epoch. The epoch itself is day 0.
int daysSinceEpoch(WorldDate date, CalendarConfig config) {
  var total = 0;

  // Year part. Walk forward from startYear (or backward) summing year lengths.
  if (date.year >= config.startYear) {
    for (var y = config.startYear; y < date.year; y++) {
      total += config.daysInYear(y);
    }
  } else {
    for (var y = config.startYear - 1; y >= date.year; y--) {
      total -= config.daysInYear(y);
    }
  }

  // Month part within `date.year`.
  for (var m = 0; m < date.monthIndex; m++) {
    total += config.daysInMonth(date.year, m);
  }

  // Day part (day is 1-based; day 1 = no offset within the month).
  total += date.day - 1;

  return total;
}

/// Inverse of [daysSinceEpoch]: turn a day count back into a [WorldDate].
WorldDate fromDaysSinceEpoch(int totalDays, CalendarConfig config) {
  var year = config.startYear;
  var remaining = totalDays;

  if (remaining >= 0) {
    while (true) {
      final yearLen = config.daysInYear(year);
      if (remaining < yearLen) break;
      remaining -= yearLen;
      year += 1;
    }
  } else {
    while (remaining < 0) {
      year -= 1;
      remaining += config.daysInYear(year);
    }
  }

  var monthIndex = 0;
  while (true) {
    final monthLen = config.daysInMonth(year, monthIndex);
    if (remaining < monthLen) break;
    remaining -= monthLen;
    monthIndex += 1;
    // Safety: months count is finite per config; loop must terminate because
    // the year-stripping above guaranteed remaining < daysInYear.
  }

  return WorldDate(year: year, monthIndex: monthIndex, day: remaining + 1);
}

/// Return `date + n` days. `n` may be negative.
WorldDate addDays(WorldDate date, int n, CalendarConfig config) {
  return fromDaysSinceEpoch(daysSinceEpoch(date, config) + n, config);
}

/// `b - a` in days. Positive when `b` is after `a`.
int daysBetween(WorldDate a, WorldDate b, CalendarConfig config) {
  return daysSinceEpoch(b, config) - daysSinceEpoch(a, config);
}

/// Weekday index (0..daysPerWeek-1). Day 0 of the epoch is weekday 0.
int weekdayAt(WorldDate date, CalendarConfig config) {
  final d = daysSinceEpoch(date, config);
  return _mod(d, config.daysPerWeek);
}

String weekdayNameAt(WorldDate date, CalendarConfig config) {
  return config.weekdayNames[weekdayAt(date, config)];
}

/// Phase of one moon at a given date.
MoonObservation moonPhaseAt(
  WorldDate date,
  MoonDef moon,
  CalendarConfig config,
) {
  final d = daysSinceEpoch(date, config);
  final cycleDay = _mod(d + moon.offsetDays, moon.periodDays);
  // Map [0, period) into 8 equal-ish phase buckets.
  // Bucket boundaries at i * period / 8 for i in [0..8].
  final phaseIndex = (cycleDay * 8) ~/ moon.periodDays;
  return MoonObservation(
    moon: moon,
    phase: MoonPhase.values[phaseIndex.clamp(0, 7)],
    dayInCycle: cycleDay,
  );
}

/// Phases for every moon defined on the world's calendar.
List<MoonObservation> moonPhasesAt(WorldDate date, CalendarConfig config) {
  return [
    for (final moon in config.moons) moonPhaseAt(date, moon, config),
  ];
}

/// Human-readable form: "12 Hammer, 1493 DR (Sul)".
String formatDate(WorldDate date, CalendarConfig config) {
  final monthName = config.months[date.monthIndex].name;
  final weekday = weekdayNameAt(date, config);
  return '${date.day} $monthName, ${date.year} ${config.epochName} ($weekday)';
}

/// Mathematical mod that always returns a non-negative result.
int _mod(int a, int n) {
  final r = a % n;
  return r < 0 ? r + n : r;
}
