import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'create_world_screen.dart';
import 'join_world_screen.dart';
import 'models/world.dart';
import 'world_detail_screen.dart';
import 'world_providers.dart';

class WorldListScreen extends ConsumerWidget {
  const WorldListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final name = user?.displayName ?? user?.email ?? 'Adventurer';
    final worlds = ref.watch(myWorldsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('D&D Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Join with code',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JoinWorldScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateWorldScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New world'),
      ),
      body: worlds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(name: name);
          }
          final myUid = user?.uid;
          final dmd = list.where((w) => w.ownerUid == myUid).toList();
          final joined = list.where((w) => w.ownerUid != myUid).toList();
          return ListView(
            children: [
              if (dmd.isNotEmpty) ...[
                const _SectionHeader('You DM'),
                for (final w in dmd) _WorldTile(world: w, isOwner: true),
              ],
              if (joined.isNotEmpty) ...[
                const _SectionHeader('You joined'),
                for (final w in joined) _WorldTile(world: w, isOwner: false),
              ],
            ],
          );
        },
      ),
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

class _WorldTile extends StatelessWidget {
  const _WorldTile({required this.world, required this.isOwner});

  final World world;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final cal = world.calendar;
    final subtitle = '${cal.months.length} months · '
        '${cal.daysPerWeek}-day week · '
        '${cal.moons.length} moon(s)';
    return ListTile(
      leading: Icon(isOwner ? Icons.shield : Icons.person),
      title: Text(world.name),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorldDetailScreen(worldId: world.id),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.castle, size: 64),
            const SizedBox(height: 16),
            Text(
              'Welcome, $name',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'No worlds yet. Create one with the + button, or use the '
              'login icon in the app bar to join with a code.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
