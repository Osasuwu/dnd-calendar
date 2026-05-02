import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'world.dart';

part 'event.freezed.dart';
part 'event.g.dart';

enum EventStatus { scheduled, completed, cancelled }

@freezed
class Event with _$Event {
  const Event._();
  const factory Event({
    required String id,
    required String worldId,
    required String title,
    @Default('') String description,
    required WorldDateData startDate,
    WorldDateData? endDate,
    int? capacity,
    required WorldDateData registrationDeadline,
    @Default(EventStatus.scheduled) EventStatus status,
    required String createdByUid,
    @TimestampConverter() DateTime? createdAt,
  }) = _Event;
  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  factory Event.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String worldId,
  ) {
    final data = doc.data()!;
    return Event.fromJson({...data, 'id': doc.id, 'worldId': worldId});
  }

  Map<String, dynamic> toFirestore() {
    final j = toJson();
    j.remove('id');
    j.remove('worldId');
    return j;
  }
}
