import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'models/world.dart';
import 'world_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final worldRepositoryProvider = Provider<WorldRepository>(
  (ref) => WorldRepository(ref.watch(firestoreProvider)),
);

/// Worlds owned by the signed-in user. Empty list while signed out.
final ownedWorldsProvider = StreamProvider<List<World>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return Stream.value(<World>[]);
  return ref.watch(worldRepositoryProvider).watchOwnedWorlds(user.uid);
});

/// World ids the signed-in user joined as a player.
final joinedWorldIdsProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return Stream.value(<String>[]);
  return ref.watch(worldRepositoryProvider).watchJoinedWorldIds(user.uid);
});

/// All worlds visible to the signed-in user — owned + joined (deduped),
/// owned first. Loading until both source streams have emitted at least
/// once. Each joined world stays live via the per-id [worldProvider].
final myWorldsProvider = Provider<AsyncValue<List<World>>>((ref) {
  final ownedAsync = ref.watch(ownedWorldsProvider);
  final joinedIdsAsync = ref.watch(joinedWorldIdsProvider);

  if (ownedAsync.isLoading || joinedIdsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (ownedAsync.hasError) {
    return AsyncValue.error(ownedAsync.error!, ownedAsync.stackTrace!);
  }
  if (joinedIdsAsync.hasError) {
    return AsyncValue.error(
        joinedIdsAsync.error!, joinedIdsAsync.stackTrace!);
  }

  final owned = ownedAsync.requireValue;
  final ownedIds = owned.map((w) => w.id).toSet();
  final joinedIds = joinedIdsAsync.requireValue
      .where((id) => !ownedIds.contains(id))
      .toList();

  final joined = <World>[];
  for (final id in joinedIds) {
    final w = ref.watch(worldProvider(id)).valueOrNull;
    if (w != null) joined.add(w);
  }

  return AsyncValue.data([...owned, ...joined]);
});

/// One world by id, live.
final worldProvider = StreamProvider.family<World?, String>((ref, id) {
  return ref.watch(worldRepositoryProvider).watchWorld(id);
});
