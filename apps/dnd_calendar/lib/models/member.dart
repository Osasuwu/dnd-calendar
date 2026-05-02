import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'world.dart';

part 'member.freezed.dart';
part 'member.g.dart';

enum MemberRole { dm, player }

/// One person's membership in a world. Owner is implicit and not stored
/// here — derived from `worlds/{w}.ownerUid`.
@freezed
class Member with _$Member {
  const Member._();
  const factory Member({
    required String uid,
    required String worldId,
    @Default(MemberRole.player) MemberRole role,
    @TimestampConverter() DateTime? joinedAt,
  }) = _Member;
  factory Member.fromJson(Map<String, dynamic> json) => _$MemberFromJson(json);

  factory Member.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String worldId,
  ) {
    final data = doc.data()!;
    return Member.fromJson({...data, 'uid': doc.id, 'worldId': worldId});
  }
}
