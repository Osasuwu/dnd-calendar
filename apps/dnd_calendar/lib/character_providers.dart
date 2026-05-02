import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'character_repository.dart';
import 'models/character.dart';
import 'world_providers.dart';

final characterRepositoryProvider = Provider<CharacterRepository>(
  (ref) => CharacterRepository(ref.watch(firestoreProvider)),
);

final charactersProvider =
    StreamProvider.family<List<Character>, String>((ref, worldId) {
  return ref.watch(characterRepositoryProvider).watchCharacters(worldId);
});
