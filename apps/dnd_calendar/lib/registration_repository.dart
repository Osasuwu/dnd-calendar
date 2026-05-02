import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/registration.dart';
import 'models/world.dart';

/// Thrown when a registration would overlap an existing one for the same
/// character. Carries the conflicting registration for UI display.
class OverlapException implements Exception {
  OverlapException(this.conflict);
  final Registration conflict;
  @override
  String toString() =>
      'Character already registered for an event on overlapping dates.';
}

class RegistrationRepository {
  RegistrationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _regs(
    String worldId,
    String eventId,
  ) =>
      _db
          .collection('worlds')
          .doc(worldId)
          .collection('events')
          .doc(eventId)
          .collection('registrations');

  /// All registrations on one event, sorted by registeredAt ascending.
  Stream<List<Registration>> watchRegistrations(
    String worldId,
    String eventId,
  ) {
    return _regs(worldId, eventId)
        .orderBy('registeredAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Registration.fromFirestore(d, worldId, eventId))
            .toList());
  }

  /// Sign a character up for an event. Performs an overlap check against
  /// every existing registration of that character in this world; throws
  /// [OverlapException] on conflict.
  ///
  /// Capacity is **not** enforced here per CONTEXT.md (out of scope MVP).
  Future<void> register({
    required String worldId,
    required String eventId,
    required String uid,
    required String characterId,
    required String characterName,
    required String ownerDisplayName,
    required WorldDateData eventStartDate,
    WorldDateData? eventEndDate,
    required engine.CalendarConfig calendar,
  }) async {
    // Overlap query: all registrations across this world for this character.
    // collectionGroup matches every `registrations` subcollection in the DB;
    // we filter to this world by inspecting the doc path below.
    final snap = await _db
        .collectionGroup('registrations')
        .where('characterId', isEqualTo: characterId)
        .get();

    final newStart = eventStartDate.toEngine();
    final newEnd = (eventEndDate ?? eventStartDate).toEngine();

    for (final doc in snap.docs) {
      // Skip docs from other worlds.
      final path = doc.reference.path.split('/');
      final wIdx = path.indexOf('worlds');
      if (wIdx < 0 || wIdx + 1 >= path.length) continue;
      if (path[wIdx + 1] != worldId) continue;

      // Skip the same-event re-register case.
      final eIdx = path.indexOf('events');
      if (eIdx >= 0 && eIdx + 1 < path.length && path[eIdx + 1] == eventId) {
        continue;
      }

      final reg = Registration.fromFirestore(
        doc,
        path[wIdx + 1],
        path[eIdx + 1],
      );
      final existingStart = reg.eventStartDate.toEngine();
      final existingEnd = (reg.eventEndDate ?? reg.eventStartDate).toEngine();

      // Inclusive overlap: ranges share at least one day iff
      //   newStart <= existingEnd && existingStart <= newEnd
      final newStartDays = engine.daysSinceEpoch(newStart, calendar);
      final newEndDays = engine.daysSinceEpoch(newEnd, calendar);
      final existingStartDays = engine.daysSinceEpoch(existingStart, calendar);
      final existingEndDays = engine.daysSinceEpoch(existingEnd, calendar);

      if (newStartDays <= existingEndDays && existingStartDays <= newEndDays) {
        throw OverlapException(reg);
      }
    }

    await _regs(worldId, eventId).doc(uid).set({
      'characterId': characterId,
      'characterName': characterName,
      'ownerDisplayName': ownerDisplayName,
      'eventStartDate': eventStartDate.toJson(),
      'eventEndDate': eventEndDate?.toJson(),
      'registeredAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unregister({
    required String worldId,
    required String eventId,
    required String uid,
  }) async {
    await _regs(worldId, eventId).doc(uid).delete();
  }
}
