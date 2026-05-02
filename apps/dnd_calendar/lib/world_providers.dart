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
final myWorldsProvider = StreamProvider<List<World>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return Stream.value(<World>[]);
  return ref.watch(worldRepositoryProvider).watchWorldsForUser(user.uid);
});

/// One world by id.
final worldProvider = StreamProvider.family<World?, String>((ref, id) {
  return ref.watch(worldRepositoryProvider).watchWorld(id);
});
