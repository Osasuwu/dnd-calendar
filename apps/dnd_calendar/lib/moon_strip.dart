import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:flutter/material.dart';

import 'models/world.dart';

/// Compact one-line indicator like "🌒 Moon 5/28 · 🌕 Selûne 14/28".
class MoonStrip extends StatelessWidget {
  const MoonStrip({
    super.key,
    required this.calendar,
    required this.date,
    this.style,
  });

  final CalendarConfigData calendar;
  final WorldDateData date;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = calendar.toEngine();
    final phases = engine.moonPhasesAt(date.toEngine(), c);
    if (phases.isEmpty) {
      return Text(
        'No moons configured.',
        style: style ?? Theme.of(context).textTheme.bodySmall,
      );
    }
    final defaultStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final p in phases)
          Text(
            '${p.phase.symbol} ${p.moon.name} '
            '${p.dayInCycle + 1}/${p.moon.periodDays}',
            style: defaultStyle,
          ),
      ],
    );
  }
}
