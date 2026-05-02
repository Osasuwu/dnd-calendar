import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'character_providers.dart';
import 'event_edit_screen.dart';
import 'event_providers.dart';
import 'models/character.dart';
import 'models/event.dart';
import 'models/registration.dart';
import 'models/world.dart';
import 'registration_providers.dart';
import 'registration_repository.dart';
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
    final regsAsync = ref.watch(
      registrationsProvider((worldId: event.worldId, eventId: event.id)),
    );
    final me = ref.watch(authStateChangesProvider).valueOrNull;
    final regCount = regsAsync.valueOrNull?.length ?? 0;
    final myReg = regsAsync.valueOrNull?.firstWhere(
      (r) => r.uid == me?.uid,
      orElse: () => Registration(
        uid: '',
        worldId: '',
        eventId: '',
        characterId: '',
        eventStartDate: event.startDate,
      ),
    );
    final iAmRegistered = myReg != null && myReg.uid.isNotEmpty;

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
          event.capacity == null
              ? '$regCount signed up · unlimited'
              : '$regCount / ${event.capacity}',
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
        const SizedBox(height: 16),
        const Divider(),
        // Sign-up actions
        if (event.status == EventStatus.cancelled)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'This event was cancelled — sign-ups are closed.',
              style: TextStyle(fontSize: 13),
            ),
          )
        else if (me != null) ...[
          if (iAmRegistered)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.logout),
              label: Text(
                'Unregister ${myReg.characterName.isEmpty ? '' : '(${myReg.characterName})'}',
              ),
              onPressed: () => _unregister(context, ref, me.uid),
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.how_to_reg),
              label: const Text('Sign up'),
              onPressed: () => _openSignUp(context, ref, me.uid, c),
            ),
        ],
        const SizedBox(height: 16),
        Text('Registrations', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        regsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (regs) {
            if (regs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No one has signed up yet.',
                  style: TextStyle(fontSize: 13),
                ),
              );
            }
            return Column(
              children: [
                for (final r in regs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person),
                    title: Text(
                      r.characterName.isEmpty
                          ? '(unnamed character)'
                          : r.characterName,
                    ),
                    subtitle: Text(
                      r.ownerDisplayName.isEmpty
                          ? r.uid
                          : 'by ${r.ownerDisplayName}',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openSignUp(
    BuildContext context,
    WidgetRef ref,
    String uid,
    engine.CalendarConfig calendar,
  ) async {
    final charsAsync = ref.read(charactersProvider(event.worldId));
    final chars = charsAsync.valueOrNull ?? [];
    final mine = chars.where((c) => c.uid == uid).toList();
    if (mine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a character first (Characters tab).'),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<Character>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child:
                  Text('Pick a character', style: TextStyle(fontSize: 16)),
            ),
            for (final c in mine)
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(c.name),
                subtitle: Text(
                  '${c.characterClass.isEmpty ? '—' : c.characterClass} · '
                  'Level ${c.level}',
                ),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    try {
      await ref.read(registrationRepositoryProvider).register(
            worldId: event.worldId,
            eventId: event.id,
            uid: uid,
            characterId: picked.id,
            characterName: picked.name,
            ownerDisplayName: picked.ownerDisplayName,
            eventStartDate: event.startDate,
            eventEndDate: event.endDate,
            calendar: calendar,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${picked.name} signed up.')),
        );
      }
    } on OverlapException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${picked.name} is already signed up for "${e.conflict.characterName}\'s" '
              'event on overlapping dates.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-up failed: $e')),
        );
      }
    }
  }

  Future<void> _unregister(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    await ref.read(registrationRepositoryProvider).unregister(
          worldId: event.worldId,
          eventId: event.id,
          uid: uid,
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
