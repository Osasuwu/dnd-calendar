import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'character.freezed.dart';
part 'character.g.dart';

/// Thin character card scoped to one (user, world). Full character sheet
/// lives outside the app — this is just enough to identify a character at
/// quest sign-up.
///
/// `ownerDisplayName` is denormalized from Firebase Auth at write time so
/// the DM and other players can see whose character is whose without an
/// extra users-collection lookup.
@freezed
class Character with _$Character {
  const Character._();
  const factory Character({
    required String id,
    required String worldId,
    required String uid,
    @Default('') String ownerDisplayName,
    required String name,
    @Default('') String characterClass,
    @Default(1) int level,
  }) = _Character;
  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);

  factory Character.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String worldId,
  ) {
    final data = doc.data()!;
    return Character.fromJson({...data, 'id': doc.id, 'worldId': worldId});
  }

  Map<String, dynamic> toFirestore() {
    final j = toJson();
    j.remove('id');
    j.remove('worldId');
    return j;
  }
}
