import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/world.dart';

/// Pick a [WorldDateData] using the world's own calendar config (custom
/// weekday/month/day vocabulary). The standard Material DatePicker is
/// useless here because it assumes Earth-Gregorian.
class WorldDatePicker extends StatefulWidget {
  const WorldDatePicker({
    super.key,
    required this.calendar,
    required this.initial,
    required this.onChanged,
    this.label,
  });

  final CalendarConfigData calendar;
  final WorldDateData initial;
  final ValueChanged<WorldDateData> onChanged;
  final String? label;

  @override
  State<WorldDatePicker> createState() => _WorldDatePickerState();
}

class _WorldDatePickerState extends State<WorldDatePicker> {
  late int _year;
  late int _monthIndex;
  late int _day;
  late TextEditingController _yearCtl;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _monthIndex = widget.initial.monthIndex;
    _day = widget.initial.day;
    _yearCtl = TextEditingController(text: _year.toString());
  }

  @override
  void dispose() {
    _yearCtl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      WorldDateData(year: _year, monthIndex: _monthIndex, day: _day),
    );
  }

  int _daysInMonth() {
    final c = widget.calendar.toEngine();
    return c.daysInMonth(_year, _monthIndex);
  }

  String _weekdayName() {
    final c = widget.calendar.toEngine();
    final d = engine.WorldDate(year: _year, monthIndex: _monthIndex, day: _day);
    return engine.weekdayNameAt(d, c);
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.calendar.months;
    final monthIndex = _monthIndex.clamp(0, months.length - 1);
    final daysIn = _daysInMonth();
    final clampedDay = _day.clamp(1, daysIn);
    if (clampedDay != _day) {
      _day = clampedDay;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            // Year
            SizedBox(
              width: 96,
              child: TextField(
                controller: _yearCtl,
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final y = int.tryParse(v);
                  if (y != null) {
                    setState(() => _year = y);
                    _emit();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Month
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: monthIndex,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  for (var i = 0; i < months.length; i++)
                    DropdownMenuItem(value: i, child: Text(months[i].name)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _monthIndex = v);
                    _emit();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Day
            SizedBox(
              width: 84,
              child: DropdownButtonFormField<int>(
                initialValue: _day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [
                  for (var d = 1; d <= daysIn; d++)
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _day = v);
                    _emit();
                  }
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _weekdayName(),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      ],
    );
  }
}
