/// Definition of one moon in a world's sky. Phase at any date is computed
/// from `(daysSinceEpoch + offsetDays) mod periodDays`.
class MoonDef {
  const MoonDef({
    required this.name,
    required this.periodDays,
    required this.offsetDays,
    required this.color,
  }) : assert(periodDays > 0, 'periodDays must be positive');

  final String name;
  final int periodDays;
  final int offsetDays;
  final String color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoonDef &&
          other.name == name &&
          other.periodDays == periodDays &&
          other.offsetDays == offsetDays &&
          other.color == color;

  @override
  int get hashCode => Object.hash(name, periodDays, offsetDays, color);
}

/// Standard 8 lunar phases in order around the cycle.
enum MoonPhase {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent;

  /// Short symbol for textual UI rendering (e.g. "🌒 2/8").
  String get symbol {
    switch (this) {
      case MoonPhase.newMoon:
        return '🌑';
      case MoonPhase.waxingCrescent:
        return '🌒';
      case MoonPhase.firstQuarter:
        return '🌓';
      case MoonPhase.waxingGibbous:
        return '🌔';
      case MoonPhase.fullMoon:
        return '🌕';
      case MoonPhase.waningGibbous:
        return '🌖';
      case MoonPhase.lastQuarter:
        return '🌗';
      case MoonPhase.waningCrescent:
        return '🌘';
    }
  }
}

/// One observation of a moon at a given date.
class MoonObservation {
  const MoonObservation({
    required this.moon,
    required this.phase,
    required this.dayInCycle,
  });

  final MoonDef moon;
  final MoonPhase phase;

  /// Day-of-cycle, 0..periodDays-1. Useful for "🌒 2/8"-style UI.
  final int dayInCycle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoonObservation &&
          other.moon == moon &&
          other.phase == phase &&
          other.dayInCycle == dayInCycle;

  @override
  int get hashCode => Object.hash(moon, phase, dayInCycle);
}
