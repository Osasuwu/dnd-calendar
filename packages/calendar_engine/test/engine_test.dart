import 'package:calendar_engine/calendar_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarConfig — base shape', () {
    test('daysInYear sums all months without leap rule', () {
      final c = _harptos();
      expect(c.daysInYear(1), 360); // 12 * 30
    });

    test('daysInMonth honors leap rule on configured month', () {
      final c = _harptos();
      // leapRule: every 4 years, +1 day to month index 6
      expect(c.daysInMonth(1, 6), 30);
      expect(c.daysInMonth(4, 6), 31);
      // Other months unaffected even on a leap year.
      expect(c.daysInMonth(4, 0), 30);
    });

    test('daysInYear is +1 on a leap year', () {
      final c = _harptos();
      expect(c.daysInYear(4), 361);
    });

    test('isValidDate rejects out-of-range months/days', () {
      final c = _harptos();
      expect(c.isValidDate(1, 0, 1), isTrue);
      expect(c.isValidDate(1, 0, 30), isTrue);
      expect(c.isValidDate(1, 0, 31), isFalse); // base month is 30 days
      expect(c.isValidDate(4, 6, 31), isTrue); // leap year extends month 6
      expect(c.isValidDate(1, 12, 1), isFalse); // only 12 months (0..11)
      expect(c.isValidDate(1, -1, 1), isFalse);
    });
  });

  group('daysSinceEpoch', () {
    test('epoch itself is 0', () {
      final c = _harptos();
      expect(daysSinceEpoch(const WorldDate(year: 1, monthIndex: 0, day: 1), c),
          0);
    });

    test('counts within first month', () {
      final c = _harptos();
      expect(daysSinceEpoch(const WorldDate(year: 1, monthIndex: 0, day: 15), c),
          14);
    });

    test('counts across months in the same year', () {
      final c = _harptos();
      // 1/2/1 = 30 days into year (skipped all of month 0)
      expect(daysSinceEpoch(const WorldDate(year: 1, monthIndex: 1, day: 1), c),
          30);
    });

    test('counts across years (no leap years in between)', () {
      final c = _harptos();
      // year 2, month 0, day 1 = exactly 360 days after epoch
      expect(daysSinceEpoch(const WorldDate(year: 2, monthIndex: 0, day: 1), c),
          360);
    });

    test('counts across a leap year', () {
      final c = _harptos();
      // year 5, month 0, day 1 = 360 + 360 + 360 + 361 = 1441
      expect(daysSinceEpoch(const WorldDate(year: 5, monthIndex: 0, day: 1), c),
          1441);
    });

    test('returns negative for dates before the epoch', () {
      final c = _harptos();
      // startYear is 1, so year 0 is the year *before* the epoch. Year 0 is
      // a leap year under `year % 4 == 0`, so it has 361 days; the last day
      // of year 0 is the day right before (1, 0, 1).
      expect(daysSinceEpoch(const WorldDate(year: 0, monthIndex: 11, day: 30), c),
          -1);
      expect(daysSinceEpoch(const WorldDate(year: 0, monthIndex: 0, day: 1), c),
          -361);
    });
  });

  group('addDays', () {
    test('zero is identity', () {
      final c = _harptos();
      const d = WorldDate(year: 3, monthIndex: 5, day: 12);
      expect(addDays(d, 0, c), d);
    });

    test('overflows month boundary', () {
      final c = _harptos();
      const d = WorldDate(year: 1, monthIndex: 0, day: 28);
      expect(addDays(d, 5, c), const WorldDate(year: 1, monthIndex: 1, day: 3));
    });

    test('overflows year boundary', () {
      final c = _harptos();
      const d = WorldDate(year: 1, monthIndex: 11, day: 28);
      expect(addDays(d, 5, c), const WorldDate(year: 2, monthIndex: 0, day: 3));
    });

    test('skips into a leap year correctly', () {
      final c = _harptos();
      // year 4 month 6 has 31 days; year 4 month 7 day 1 = 30 + 30*5 + 31 = 211 days into year 4.
      // year 4 month 6 day 30 + 1 day should give month 6 day 31, not month 7 day 1.
      const d = WorldDate(year: 4, monthIndex: 6, day: 30);
      expect(addDays(d, 1, c), const WorldDate(year: 4, monthIndex: 6, day: 31));
      // and +2 should go to month 7 day 1.
      expect(addDays(d, 2, c), const WorldDate(year: 4, monthIndex: 7, day: 1));
    });

    test('accepts negative offsets', () {
      final c = _harptos();
      const d = WorldDate(year: 2, monthIndex: 0, day: 5);
      expect(addDays(d, -10, c), const WorldDate(year: 1, monthIndex: 11, day: 25));
    });

    test('round-trips with daysSinceEpoch', () {
      final c = _harptos();
      const d = WorldDate(year: 7, monthIndex: 4, day: 17);
      final n = daysSinceEpoch(d, c);
      expect(addDays(const WorldDate(year: 1, monthIndex: 0, day: 1), n, c), d);
    });
  });

  group('daysBetween', () {
    test('same date is 0', () {
      final c = _harptos();
      const d = WorldDate(year: 3, monthIndex: 5, day: 12);
      expect(daysBetween(d, d, c), 0);
    });

    test('positive when b is after a', () {
      final c = _harptos();
      expect(
        daysBetween(
          const WorldDate(year: 1, monthIndex: 0, day: 1),
          const WorldDate(year: 1, monthIndex: 0, day: 11),
          c,
        ),
        10,
      );
    });

    test('negative when b is before a', () {
      final c = _harptos();
      expect(
        daysBetween(
          const WorldDate(year: 1, monthIndex: 0, day: 11),
          const WorldDate(year: 1, monthIndex: 0, day: 1),
          c,
        ),
        -10,
      );
    });

    test('counts a leap day when crossing one', () {
      final c = _harptos();
      // Year 4 has 361 days; year 1 to year 5 spans years 1,2,3,4 = 360+360+360+361 = 1441
      expect(
        daysBetween(
          const WorldDate(year: 1, monthIndex: 0, day: 1),
          const WorldDate(year: 5, monthIndex: 0, day: 1),
          c,
        ),
        1441,
      );
    });
  });

  group('weekdayAt', () {
    test('epoch is weekday 0', () {
      final c = _harptos();
      expect(weekdayAt(const WorldDate(year: 1, monthIndex: 0, day: 1), c), 0);
    });

    test('wraps after daysPerWeek', () {
      final c = _harptos();
      expect(weekdayAt(const WorldDate(year: 1, monthIndex: 0, day: 8), c), 0);
      expect(weekdayAt(const WorldDate(year: 1, monthIndex: 0, day: 9), c), 1);
    });

    test('weekdayNameAt returns the configured name', () {
      final c = _harptos();
      expect(
        weekdayNameAt(const WorldDate(year: 1, monthIndex: 0, day: 1), c),
        'Sul',
      );
    });

    test('handles negative dates correctly (no negative weekday)', () {
      final c = _harptos();
      // Day -1 should be weekday 6 (last weekday).
      expect(
        weekdayAt(const WorldDate(year: 0, monthIndex: 11, day: 30), c),
        6,
      );
    });
  });

  group('moonPhaseAt', () {
    test('newMoon at offset 0 on epoch', () {
      final c = _harptos();
      final selune = c.moons.first; // period 28, offset 0
      final obs = moonPhaseAt(
        const WorldDate(year: 1, monthIndex: 0, day: 1),
        selune,
        c,
      );
      expect(obs.phase, MoonPhase.newMoon);
      expect(obs.dayInCycle, 0);
    });

    test('full moon halfway through cycle', () {
      final c = _harptos();
      final selune = c.moons.first;
      // period 28 → fullMoon at indices 14..16 (since cycleDay*8 ~/ 28).
      final obs = moonPhaseAt(
        const WorldDate(year: 1, monthIndex: 0, day: 15),
        selune,
        c,
      );
      expect(obs.dayInCycle, 14);
      expect(obs.phase, MoonPhase.fullMoon);
    });

    test('phase index honors moon offsetDays', () {
      // Moon with periodDays 8 and offset 4 → on epoch it's already at cycleDay 4 (fullMoon).
      final m = const MoonDef(
        name: 'TestMoon',
        periodDays: 8,
        offsetDays: 4,
        color: '#fff',
      );
      final c = _harptos();
      final obs = moonPhaseAt(
        const WorldDate(year: 1, monthIndex: 0, day: 1),
        m,
        c,
      );
      expect(obs.dayInCycle, 4);
      expect(obs.phase, MoonPhase.fullMoon);
    });

    test('moonPhasesAt returns one observation per defined moon', () {
      final c = _harptos();
      final phases = moonPhasesAt(
        const WorldDate(year: 1, monthIndex: 0, day: 1),
        c,
      );
      expect(phases, hasLength(2));
      expect(phases[0].moon.name, 'Selûne');
      expect(phases[1].moon.name, 'Anadia');
    });

    test('phase advances as days advance', () {
      final c = _harptos();
      final selune = c.moons.first; // period 28
      final phases = <MoonPhase>{};
      for (var i = 0; i < 28; i++) {
        phases.add(moonPhaseAt(
          addDays(const WorldDate(year: 1, monthIndex: 0, day: 1), i, c),
          selune,
          c,
        ).phase);
      }
      // Over a full cycle every one of the 8 phases must show up at least once.
      expect(phases, hasLength(8));
    });
  });

  group('formatDate', () {
    test('renders day, month, year, epoch and weekday', () {
      final c = _harptos();
      expect(
        formatDate(const WorldDate(year: 1, monthIndex: 0, day: 1), c),
        '1 Hammer, 1 DR (Sul)',
      );
    });
  });
}

/// A roughly Forgotten-Realms-style "Calendar of Harptos" fixture:
/// 12 months × 30 days, 7-day week, +1 day to Flamerule (month 6) every
/// 4 years, plus two moons (Selûne 28d, Anadia 90d).
CalendarConfig _harptos() => const CalendarConfig(
      daysPerWeek: 7,
      weekdayNames: ['Sul', 'Mol', 'Zor', 'Wuk', 'Lok', 'Eko', 'Ano'],
      months: [
        MonthDef(name: 'Hammer', days: 30),
        MonthDef(name: 'Alturiak', days: 30),
        MonthDef(name: 'Ches', days: 30),
        MonthDef(name: 'Tarsakh', days: 30),
        MonthDef(name: 'Mirtul', days: 30),
        MonthDef(name: 'Kythorn', days: 30),
        MonthDef(name: 'Flamerule', days: 30),
        MonthDef(name: 'Eleasis', days: 30),
        MonthDef(name: 'Eleint', days: 30),
        MonthDef(name: 'Marpenoth', days: 30),
        MonthDef(name: 'Uktar', days: 30),
        MonthDef(name: 'Nightal', days: 30),
      ],
      epochName: 'DR',
      startYear: 1,
      leapRule: LeapRule(everyNYears: 4, extraDayInMonthIndex: 6),
      moons: [
        MoonDef(name: 'Selûne', periodDays: 28, offsetDays: 0, color: '#ddddff'),
        MoonDef(name: 'Anadia', periodDays: 90, offsetDays: 10, color: '#ffeecc'),
      ],
    );

