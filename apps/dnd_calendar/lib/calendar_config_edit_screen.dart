import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/world.dart';
import 'world_providers.dart';

/// Owner-only screen for editing the calendar config of one world. The whole
/// form lives in local state and is committed atomically on Save.
class CalendarConfigEditScreen extends ConsumerStatefulWidget {
  const CalendarConfigEditScreen({
    super.key,
    required this.worldId,
    required this.initial,
  });

  final String worldId;
  final CalendarConfigData initial;

  @override
  ConsumerState<CalendarConfigEditScreen> createState() =>
      _CalendarConfigEditScreenState();
}

class _CalendarConfigEditScreenState
    extends ConsumerState<CalendarConfigEditScreen> {
  late CalendarConfigData _config;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _config = widget.initial;
  }

  // ─── Validation ──────────────────────────────────────────────────────────

  String? _validate() {
    if (_config.weekdayNames.isEmpty) {
      return 'Need at least one weekday';
    }
    if (_config.weekdayNames.length != _config.daysPerWeek) {
      return 'daysPerWeek (${_config.daysPerWeek}) must match weekday count '
          '(${_config.weekdayNames.length})';
    }
    if (_config.weekdayNames.any((n) => n.trim().isEmpty)) {
      return 'Weekday names cannot be empty';
    }
    if (_config.months.isEmpty) {
      return 'Need at least one month';
    }
    if (_config.months.any((m) => m.name.trim().isEmpty)) {
      return 'Month names cannot be empty';
    }
    if (_config.months.any((m) => m.days < 1)) {
      return 'Month length must be at least 1 day';
    }
    if (_config.epochName.trim().isEmpty) {
      return 'Epoch label is required';
    }
    final lr = _config.leapRule;
    if (lr != null) {
      if (lr.everyNYears < 1) return 'Leap rule N must be ≥ 1';
      if (lr.extraDayInMonthIndex < 0 ||
          lr.extraDayInMonthIndex >= _config.months.length) {
        return 'Leap rule month index out of range';
      }
    }
    if (_config.moons.any((m) => m.periodDays < 1)) {
      return 'Moon period must be ≥ 1';
    }
    if (_config.moons.any((m) => m.name.trim().isEmpty)) {
      return 'Moon names cannot be empty';
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(worldRepositoryProvider)
          .updateCalendar(widget.worldId, _config);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Section setters (local-state mutations) ─────────────────────────────

  void _setEpochName(String v) =>
      setState(() => _config = _config.copyWith(epochName: v));
  void _setStartYear(int v) =>
      setState(() => _config = _config.copyWith(startYear: v));

  void _setWeekday(int i, String name) {
    final next = [..._config.weekdayNames];
    next[i] = name;
    setState(() => _config = _config.copyWith(weekdayNames: next));
  }

  void _addWeekday() {
    final next = [..._config.weekdayNames, 'Day ${_config.weekdayNames.length + 1}'];
    setState(() => _config = _config.copyWith(
          weekdayNames: next,
          daysPerWeek: next.length,
        ));
  }

  void _removeWeekday(int i) {
    if (_config.weekdayNames.length <= 1) return;
    final next = [..._config.weekdayNames]..removeAt(i);
    setState(() => _config = _config.copyWith(
          weekdayNames: next,
          daysPerWeek: next.length,
        ));
  }

  void _setMonth(int i, MonthData m) {
    final next = [..._config.months];
    next[i] = m;
    setState(() => _config = _config.copyWith(months: next));
  }

  void _addMonth() {
    final next = [
      ..._config.months,
      MonthData(name: 'Month ${_config.months.length + 1}', days: 30),
    ];
    setState(() => _config = _config.copyWith(months: next));
  }

  void _removeMonth(int i) {
    if (_config.months.length <= 1) return;
    final next = [..._config.months]..removeAt(i);
    final lr = _config.leapRule;
    final newLeap = (lr != null && lr.extraDayInMonthIndex >= next.length)
        ? lr.copyWith(extraDayInMonthIndex: next.length - 1)
        : lr;
    setState(() => _config = _config.copyWith(months: next, leapRule: newLeap));
  }

  void _setLeapRule(LeapRuleData? r) =>
      setState(() => _config = _config.copyWith(leapRule: r));

  void _setMoon(int i, MoonData m) {
    final next = [..._config.moons];
    next[i] = m;
    setState(() => _config = _config.copyWith(moons: next));
  }

  void _addMoon() {
    final next = [
      ..._config.moons,
      MoonData(
        name: 'Moon ${_config.moons.length + 1}',
        periodDays: 28,
        offsetDays: 0,
        color: '#cccccc',
      ),
    ];
    setState(() => _config = _config.copyWith(moons: next));
  }

  void _removeMoon(int i) {
    final next = [..._config.moons]..removeAt(i);
    setState(() => _config = _config.copyWith(moons: next));
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit calendar'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          _PreviewCard(config: _config),
          _EpochCard(
            epochName: _config.epochName,
            startYear: _config.startYear,
            onEpochName: _setEpochName,
            onStartYear: _setStartYear,
          ),
          _WeekdaysCard(
            weekdays: _config.weekdayNames,
            onSet: _setWeekday,
            onAdd: _addWeekday,
            onRemove: _removeWeekday,
          ),
          _MonthsCard(
            months: _config.months,
            onSet: _setMonth,
            onAdd: _addMonth,
            onRemove: _removeMonth,
          ),
          _LeapRuleCard(
            rule: _config.leapRule,
            monthCount: _config.months.length,
            monthNames: [for (final m in _config.months) m.name],
            onChange: _setLeapRule,
          ),
          _MoonsCard(
            moons: _config.moons,
            onSet: _setMoon,
            onAdd: _addMoon,
            onRemove: _removeMoon,
          ),
        ],
      ),
    );
  }
}

// ─── Preview ────────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.config});

  final CalendarConfigData config;

  @override
  Widget build(BuildContext context) {
    String preview;
    String yearLen;
    try {
      final c = config.toEngine();
      final today = config.currentDate.toEngine();
      preview = engine.formatDate(today, c);
      yearLen = '${c.daysInYear(today.year)} days/year';
    } catch (e) {
      preview = '(invalid config: $e)';
      yearLen = '';
    }
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Preview', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(preview, style: Theme.of(context).textTheme.titleMedium),
            if (yearLen.isNotEmpty)
              Text(yearLen, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─── Sections ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _EpochCard extends StatelessWidget {
  const _EpochCard({
    required this.epochName,
    required this.startYear,
    required this.onEpochName,
    required this.onStartYear,
  });

  final String epochName;
  final int startYear;
  final ValueChanged<String> onEpochName;
  final ValueChanged<int> onStartYear;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Epoch',
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: epochName,
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: onEpochName,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: startYear.toString(),
              decoration: const InputDecoration(labelText: 'Start year'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => onStartYear(int.tryParse(v) ?? startYear),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdaysCard extends StatelessWidget {
  const _WeekdaysCard({
    required this.weekdays,
    required this.onSet,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> weekdays;
  final void Function(int, String) onSet;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Weekdays (${weekdays.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < weekdays.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('weekday-$i-${weekdays[i]}'),
                      initialValue: weekdays[i],
                      decoration: InputDecoration(labelText: 'Day ${i + 1}'),
                      onChanged: (v) => onSet(i, v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed:
                        weekdays.length > 1 ? () => onRemove(i) : null,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add weekday'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthsCard extends StatelessWidget {
  const _MonthsCard({
    required this.months,
    required this.onSet,
    required this.onAdd,
    required this.onRemove,
  });

  final List<MonthData> months;
  final void Function(int, MonthData) onSet;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Months (${months.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < months.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      key: ValueKey('month-name-$i-${months[i].name}'),
                      initialValue: months[i].name,
                      decoration:
                          InputDecoration(labelText: 'Month ${i + 1} name'),
                      onChanged: (v) =>
                          onSet(i, months[i].copyWith(name: v)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('month-days-$i-${months[i].days}'),
                      initialValue: months[i].days.toString(),
                      decoration: const InputDecoration(labelText: 'Days'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final d = int.tryParse(v);
                        if (d != null && d > 0) {
                          onSet(i, months[i].copyWith(days: d));
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: months.length > 1 ? () => onRemove(i) : null,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add month'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeapRuleCard extends StatelessWidget {
  const _LeapRuleCard({
    required this.rule,
    required this.monthCount,
    required this.monthNames,
    required this.onChange,
  });

  final LeapRuleData? rule;
  final int monthCount;
  final List<String> monthNames;
  final ValueChanged<LeapRuleData?> onChange;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Leap rule',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            subtitle: const Text(
              'Adds 1 day to a chosen month every N years',
              style: TextStyle(fontSize: 12),
            ),
            value: rule != null,
            onChanged: (v) => onChange(
              v
                  ? const LeapRuleData(everyNYears: 4, extraDayInMonthIndex: 0)
                  : null,
            ),
          ),
          if (rule != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('leap-n-${rule!.everyNYears}'),
                    initialValue: rule!.everyNYears.toString(),
                    decoration:
                        const InputDecoration(labelText: 'Every N years'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) {
                        onChange(rule!.copyWith(everyNYears: n));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        rule!.extraDayInMonthIndex.clamp(0, monthCount - 1),
                    decoration: const InputDecoration(labelText: 'Add day to'),
                    items: [
                      for (var i = 0; i < monthCount; i++)
                        DropdownMenuItem(value: i, child: Text(monthNames[i])),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        onChange(rule!.copyWith(extraDayInMonthIndex: v));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MoonsCard extends StatelessWidget {
  const _MoonsCard({
    required this.moons,
    required this.onSet,
    required this.onAdd,
    required this.onRemove,
  });

  final List<MoonData> moons;
  final void Function(int, MoonData) onSet;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Moons (${moons.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < moons.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: ValueKey('moon-name-$i-${moons[i].name}'),
                          initialValue: moons[i].name,
                          decoration: const InputDecoration(labelText: 'Name'),
                          onChanged: (v) =>
                              onSet(i, moons[i].copyWith(name: v)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => onRemove(i),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('moon-period-$i-${moons[i].periodDays}'),
                          initialValue: moons[i].periodDays.toString(),
                          decoration: const InputDecoration(
                              labelText: 'Period (days)'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) {
                            final p = int.tryParse(v);
                            if (p != null && p > 0) {
                              onSet(i, moons[i].copyWith(periodDays: p));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('moon-offset-$i-${moons[i].offsetDays}'),
                          initialValue: moons[i].offsetDays.toString(),
                          decoration: const InputDecoration(labelText: 'Offset'),
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true),
                          onChanged: (v) {
                            final o = int.tryParse(v);
                            if (o != null) {
                              onSet(i, moons[i].copyWith(offsetDays: o));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('moon-color-$i-${moons[i].color}'),
                          initialValue: moons[i].color,
                          decoration: const InputDecoration(
                            labelText: 'Color',
                            hintText: '#rrggbb',
                          ),
                          onChanged: (v) =>
                              onSet(i, moons[i].copyWith(color: v)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add moon'),
            ),
          ),
        ],
      ),
    );
  }
}
