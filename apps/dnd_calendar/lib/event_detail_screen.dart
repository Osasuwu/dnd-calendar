import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'event_edit_screen.dart';
import 'event_providers.dart';
import 'models/event.dart';
import 'models/world.dart';
import 'world_providers.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({
    super.key,
    required this.worldId,
    required this.eventId,
  });

  final String worldId;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync =
        ref.watch(eventProvider((worldId: worldId, eventId: eventId)));
    final worldAsync = ref.watch(worldProvider(worldId));
    final me = ref.watch(authStateChangesProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Event not found.'));
          }
          return worldAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (world) {
              if (world == null) {
                return const Center(child: Text('World not found.'));
              }
              return _Body(
                event: event,
                world: world.calendar,
                isOwner: me?.uid == world.ownerUid,
              );
            },
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.event,
    required this.world,
    required this.isOwner,
  });

  final Event event;
  final CalendarConfigData world;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = world.toEngine();
    final start = engine.formatDate(event.startDate.toEngine(), c);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            _StatusBadge(status: event.status),
          ],
        ),
        const SizedBox(height: 12),
        _kv(context, 'When', start),
        if (event.registrationDeadline != event.startDate)
          _kv(
            context,
            'Sign-up by',
            engine.formatDate(event.registrationDeadline.toEngine(), c),
          ),
        _kv(
          context,
          'Capacity',
          event.capacity == null ? 'unlimited' : '0 / ${event.capacity}',
        ),
        const SizedBox(height: 16),
        if (event.description.isNotEmpty)
          Text(event.description, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 24),
        if (isOwner) ...[
          const Divider(),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventEditScreen(
                      worldId: event.worldId,
                      calendar: world,
                      existing: event,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
              if (event.status != EventStatus.cancelled)
                OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, ref),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel event'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Player registration lands in S6.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text(
          'It will be marked as cancelled. Registrations stay visible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(eventRepositoryProvider)
        .setStatus(event.worldId, event.id, EventStatus.cancelled);
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child:
                  Text(k, style: TextStyle(color: Theme.of(context).hintColor)),
            ),
            Expanded(child: Text(v)),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EventStatus.scheduled => ('Scheduled', Colors.blue),
      EventStatus.completed => ('Completed', Colors.green),
      EventStatus.cancelled => ('Cancelled', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
