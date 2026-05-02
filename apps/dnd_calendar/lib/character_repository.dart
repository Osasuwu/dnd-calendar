import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/character.dart';

class CharacterRepository {
  CharacterRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _characters(String worldId) =>
      _db.collection('worlds').doc(worldId).collection('characters');

  Stream<List<Character>> watchCharacters(String worldId) {
    return _characters(worldId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Character.fromFirestore(d, worldId))
            .toList());
  }

  Stream<Character?> watchCharacter(String worldId, String characterId) {
    return _characters(worldId).doc(characterId).snapshots().map(
          (d) => d.exists ? Character.fromFirestore(d, worldId) : null,
        );
  }

  Future<String> createCharacter(Character c) async {
    final doc = _characters(c.worldId).doc();
    await doc.set(c.toFirestore());
    return doc.id;
  }

  Future<void> updateCharacter(Character c) async {
    await _characters(c.worldId).doc(c.id).update(c.toFirestore());
  }

  Future<void> deleteCharacter(String worldId, String characterId) async {
    await _characters(worldId).doc(characterId).delete();
  }
}
