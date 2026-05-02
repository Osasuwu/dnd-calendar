import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'world_providers.dart';

class WorldDetailScreen extends ConsumerWidget {
  const WorldDetailScreen({super.key, required this.worldId});

  final String worldId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(worldProvider(worldId));
    final me = ref.watch(authStateChangesProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('World')),
      body: world.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (w) {
          if (w == null) {
            return const Center(child: Text('World not found.'));
          }
          final isOwner = me?.uid == w.ownerUid;
          final cal = w.calendar.toEngine();
          final today = w.calendar.currentDate.toEngine();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(w.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              if (isOwner)
                _OwnerJoinCode(joinCode: w.joinCode)
              else
                Text('Role: player', style: Theme.of(context).textTheme.bodySmall),
              const Divider(height: 32),
              Text(
                'Calendar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _kv(context, 'Today', engine.formatDate(today, cal)),
              _kv(context, 'Week length', '${cal.daysPerWeek} days'),
              _kv(
                context,
                'Year length',
                '${cal.daysInYear(today.year)} days '
                    '(${cal.months.length} months)',
              ),
              _kv(context, 'Epoch', cal.epochName),
              _kv(context, 'Moons', cal.moons.map((m) => m.name).join(', ')),
              if (cal.leapRule != null)
                _kv(
                  context,
                  'Leap rule',
                  'Every ${cal.leapRule!.everyNYears} years +1 day',
                )
              else
                _kv(context, 'Leap rule', 'none'),
              const SizedBox(height: 32),
              const Divider(),
              const Text(
                'Events, characters, and quest registration land in later '
                'slices.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
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
