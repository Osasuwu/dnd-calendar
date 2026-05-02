import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'world.dart';

part 'registration.freezed.dart';
part 'registration.g.dart';

/// One character signed up for one event. Doc id is the player's uid so
/// each user has at most one registration per event.
///
/// Several fields (`characterName`, `ownerDisplayName`, `eventStartDate`,
/// `eventEndDate`) are denormalized so:
///  - the registrations list on event detail renders without extra lookups
///  - overlap checking can be done with a single collectionGroup query
///    over /registrations filtered by characterId
@freezed
class Registration with _$Registration {
  const Registration._();
  const factory Registration({
    required String uid,
    required String worldId,
    required String eventId,
    required String characterId,
    @Default('') String characterName,
    @Default('') String ownerDisplayName,
    required WorldDateData eventStartDate,
    WorldDateData? eventEndDate,
    @TimestampConverter() DateTime? registeredAt,
  }) = _Registration;
  factory Registration.fromJson(Map<String, dynamic> json) =>
      _$RegistrationFromJson(json);

  factory Registration.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String worldId,
    String eventId,
  ) {
    final data = doc.data()!;
    return Registration.fromJson(
      {...data, 'uid': doc.id, 'worldId': worldId, 'eventId': eventId},
    );
  }

  Map<String, dynamic> toFirestore() {
    final j = toJson();
    j.remove('uid');
    j.remove('worldId');
    j.remove('eventId');
    return j;
  }
}
