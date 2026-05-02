import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'event_detail_screen.dart';
import 'event_edit_screen.dart';
import 'event_providers.dart';
import 'models/event.dart';
import 'models/world.dart';
import 'world_providers.dart';

enum _ViewMode { list, month }

/// Events tab inside the world detail screen. Owner can create events;
/// everyone can view. Toggle between chronological list and one-month grid.
class EventsSection extends ConsumerStatefulWidget {
  const EventsSection({
    super.key,
    required this.worldId,
    required this.calendar,
  });

  final String worldId;
  final CalendarConfigData calendar;

  @override
  ConsumerState<EventsSection> createState() => _EventsSectionState();
}

class _EventsSectionState extends ConsumerState<EventsSection> {
  _ViewMode _mode = _ViewMode.list;
  late int _viewYear;
  late int _viewMonth;

  @override
  void initState() {
    super.initState();
    _viewYear = widget.calendar.currentDate.year;
    _viewMonth = widget.calendar.currentDate.monthIndex;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider(widget.worldId));
    final me = ref.watch(authStateChangesProvider).valueOrNull;
    final worldAsync = ref.watch(worldProvider(widget.worldId));
    final isOwner = worldAsync.valueOrNull?.ownerUid == me?.uid;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<_ViewMode>(
              segments: const [
                ButtonSegment(
                  value: _ViewMode.list,
                  label: Text('List'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment(
                  value: _ViewMode.month,
                  label: Text('Month'),
                  icon: Icon(Icons.calendar_view_month),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          Expanded(
            child: eventsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (events) {
                if (events.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No events yet.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                }
                return _mode == _ViewMode.list
                    ? _ListView(
                        events: events,
                        worldId: widget.worldId,
                        calendar: widget.calendar,
                      )
                    : _MonthView(
                        events: events,
                        worldId: widget.worldId,
                        calendar: widget.calendar,
                        year: _viewYear,
                        monthIndex: _viewMonth,
                        onPrev: _prevMonth,
                        onNext: _nextMonth,
                      );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventEditScreen(
                    worldId: widget.worldId,
                    calendar: widget.calendar,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            )
          : null,
    );
  }

  void _prevMonth() {
    setState(() {
      if (_viewMonth == 0) {
        _viewMonth = widget.calendar.months.length - 1;
        _viewYear -= 1;
      } else {
        _viewMonth -= 1;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_viewMonth == widget.calendar.months.length - 1) {
        _viewMonth = 0;
        _viewYear += 1;
      } else {
        _viewMonth += 1;
      }
    });
  }
}

class _ListView extends StatelessWidget {
  const _ListView({
    required this.events,
    required this.worldId,
    required this.calendar,
  });

  final List<Event> events;
  final String worldId;
  final CalendarConfigData calendar;

  @override
  Widget build(BuildContext context) {
    final c = calendar.toEngine();
    final today = calendar.currentDate.toEngine();
    final upcoming = <Event>[];
    final past = <Event>[];
    for (final e in events) {
      final start = e.startDate.toEngine();
      if (start.compareTo(today) >= 0) {
        upcoming.add(e);
      } else {
        past.add(e);
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (upcoming.isNotEmpty) ...[
          const _SectionHeader('Upcoming'),
          for (final e in upcoming)
            _EventTile(event: e, calendar: c, worldId: worldId),
        ],
        if (past.isNotEmpty) ...[
          const _SectionHeader('Past'),
          for (final e in past.reversed)
            _EventTile(event: e, calendar: c, worldId: worldId, dim: true),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.calendar,
    required this.worldId,
    this.dim = false,
  });

  final Event event;
  final engine.CalendarConfig calendar;
  final String worldId;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final start = engine.formatDate(event.startDate.toEngine(), calendar);
    final cancelled = event.status == EventStatus.cancelled;
    return ListTile(
      leading: Icon(
        cancelled ? Icons.cancel_outlined : Icons.event,
        color: cancelled ? Colors.red : null,
      ),
      title: Text(
        event.title,
        style: TextStyle(
          decoration: cancelled ? TextDecoration.lineThrough : null,
          color: dim ? Theme.of(context).hintColor : null,
        ),
      ),
      subtitle: Text(start),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(
            worldId: worldId,
            eventId: event.id,
          ),
        ),
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.events,
    required this.worldId,
    required this.calendar,
    required this.year,
    required this.monthIndex,
    required this.onPrev,
    required this.onNext,
  });

  final List<Event> events;
  final String worldId;
  final CalendarConfigData calendar;
  final int year;
  final int monthIndex;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = calendar.toEngine();
    final monthName = calendar.months[monthIndex].name;
    final daysInMonth = c.daysInMonth(year, monthIndex);
    final firstWeekday = engine.weekdayAt(
      engine.WorldDate(year: year, monthIndex: monthIndex, day: 1),
      c,
    );
    // Group events by day-of-month for this (year, monthIndex).
    final byDay = <int, List<Event>>{};
    for (final e in events) {
      final d = e.startDate;
      if (d.year == year && d.monthIndex == monthIndex) {
        byDay.putIfAbsent(d.day, () => []).add(e);
      }
    }
    final cells = firstWeekday + daysInMonth;
    final rows = (cells / calendar.daysPerWeek).ceil();
    final today = calendar.currentDate;
    final isCurrentMonth = today.year == year && today.monthIndex == monthIndex;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Center(
                  child: Text(
                    '$monthName, $year ${calendar.epochName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                  onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (final w in calendar.weekdayNames)
                Expanded(
                  child: Center(
                    child: Text(
                      w.length > 3 ? w.substring(0, 3) : w,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 96),
            itemCount: rows,
            itemBuilder: (_, row) {
              return AspectRatio(
                aspectRatio: calendar.daysPerWeek.toDouble() / 1.0,
                child: Row(
                  children: [
                    for (var col = 0; col < calendar.daysPerWeek; col++)
                      Expanded(
                        child: _DayCell(
                          dayNumber:
                              row * calendar.daysPerWeek + col - firstWeekday + 1,
                          maxDay: daysInMonth,
                          events: byDay,
                          isToday: isCurrentMonth,
                          today: today.day,
                          worldId: worldId,
                          calendar: calendar,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.maxDay,
    required this.events,
    required this.isToday,
    required this.today,
    required this.worldId,
    required this.calendar,
  });

  final int dayNumber;
  final int maxDay;
  final Map<int, List<Event>> events;
  final bool isToday;
  final int today;
  final String worldId;
  final CalendarConfigData calendar;

  @override
  Widget build(BuildContext context) {
    if (dayNumber < 1 || dayNumber > maxDay) {
      return const SizedBox.shrink();
    }
    final dayEvents = events[dayNumber] ?? const <Event>[];
    final highlight = isToday && dayNumber == today;
    return InkWell(
      onTap: dayEvents.isEmpty
          ? null
          : () => _showDayEvents(context, dayEvents),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          color: highlight
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 12,
                fontWeight: highlight ? FontWeight.bold : null,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 2,
              children: [
                for (final e in dayEvents.take(3))
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: e.status == EventStatus.cancelled
                          ? Colors.red
                          : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (dayEvents.length > 3)
                  Text(
                    '+${dayEvents.length - 3}',
                    style: const TextStyle(fontSize: 9),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDayEvents(BuildContext context, List<Event> dayEvents) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in dayEvents)
              ListTile(
                title: Text(e.title),
                subtitle: e.status == EventStatus.cancelled
                    ? const Text('Cancelled')
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(
                        worldId: worldId,
                        eventId: e.id,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
