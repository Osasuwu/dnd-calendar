import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'calendar_config_edit_screen.dart';
import 'characters_section.dart';
import 'events_section.dart';
import 'models/world.dart';
import 'moon_strip.dart';
import 'world_date_picker.dart';
import 'world_providers.dart';

class WorldDetailScreen extends ConsumerWidget {
  const WorldDetailScreen({super.key, required this.worldId});

  final String worldId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(worldProvider(worldId));
    final me = ref.watch(authStateChangesProvider).valueOrNull;

    return world.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (w) {
        if (w == null) {
          return const Scaffold(
            body: Center(child: Text('World not found.')),
          );
        }
        final isOwner = me?.uid == w.ownerUid;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(w.name),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.castle), text: 'Overview'),
                  Tab(icon: Icon(Icons.event), text: 'Events'),
                  Tab(icon: Icon(Icons.people), text: 'Characters'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OverviewTab(world: w, isOwner: isOwner),
                EventsSection(worldId: w.id, calendar: w.calendar),
                CharactersSection(worldId: w.id),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.world, required this.isOwner});

  final World world;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = world.calendar.toEngine();
    final today = world.calendar.currentDate.toEngine();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isOwner)
          _OwnerJoinCode(joinCode: world.joinCode)
        else
          Text('Role: player', style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 32),
        // Today + moons + advance controls
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Today', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  engine.formatDate(today, cal),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                MoonStrip(calendar: world.calendar, date: world.calendar.currentDate),
                if (isOwner) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('+1 day'),
                        onPressed: () => _advanceOneDay(context, ref),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Set date…'),
                        onPressed: () => _pickDate(context, ref),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Calendar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (isOwner)
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CalendarConfigEditScreen(
                      worldId: world.id,
                      initial: world.calendar,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _kv(context, 'Week length', '${cal.daysPerWeek} days'),
        _kv(
          context,
          'Year length',
          '${cal.daysInYear(today.year)} days '
              '(${cal.months.length} months)',
        ),
        _kv(context, 'Epoch', cal.epochName),
        _kv(
          context,
          'Moons',
          cal.moons.isEmpty ? 'none' : cal.moons.map((m) => m.name).join(', '),
        ),
        if (cal.leapRule != null)
          _kv(
            context,
            'Leap rule',
            'Every ${cal.leapRule!.everyNYears} years +1 day',
          )
        else
          _kv(context, 'Leap rule', 'none'),
      ],
    );
  }

  Future<void> _advanceOneDay(BuildContext context, WidgetRef ref) async {
    final cal = world.calendar.toEngine();
    final next = engine.addDays(world.calendar.currentDate.toEngine(), 1, cal);
    await _writeDate(context, ref, WorldDateData.fromEngine(next));
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    var picked = world.calendar.currentDate;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set current date'),
        content: SizedBox(
          width: 360,
          child: WorldDatePicker(
            calendar: world.calendar,
            initial: picked,
            onChanged: (d) => picked = d,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _writeDate(context, ref, picked);
  }

  Future<void> _writeDate(
    BuildContext context,
    WidgetRef ref,
    WorldDateData newDate,
  ) async {
    try {
      await ref
          .read(worldRepositoryProvider)
          .setCurrentDate(world.id, newDate);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                k,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
            Expanded(child: Text(v)),
          ],
        ),
      );
}

class _OwnerJoinCode extends StatelessWidget {
  const _OwnerJoinCode({required this.joinCode});

  final String joinCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.vpn_key),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Join code', style: TextStyle(fontSize: 12)),
                  Text(
                    joinCode,
                    style: const TextStyle(
                      fontSize: 22,
                      fontFamily: 'monospace',
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy code',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: joinCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Join code copied')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
