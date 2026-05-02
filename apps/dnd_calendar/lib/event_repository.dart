import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/event.dart';

class EventRepository {
  EventRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _events(String worldId) =>
      _db.collection('worlds').doc(worldId).collection('events');

  Stream<List<Event>> watchEvents(String worldId) {
    return _events(worldId)
        .orderBy('startDate.year')
        .orderBy('startDate.monthIndex')
        .orderBy('startDate.day')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Event.fromFirestore(d, worldId)).toList());
  }

  Stream<Event?> watchEvent(String worldId, String eventId) {
    return _events(worldId).doc(eventId).snapshots().map(
          (d) => d.exists ? Event.fromFirestore(d, worldId) : null,
        );
  }

  Future<String> createEvent(Event event) async {
    final doc = _events(event.worldId).doc();
    await doc.set({
      ...event.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateEvent(Event event) async {
    await _events(event.worldId).doc(event.id).update(event.toFirestore());
  }

  Future<void> setStatus(
    String worldId,
    String eventId,
    EventStatus status,
  ) async {
    await _events(worldId).doc(eventId).update({'status': status.name});
  }
}
