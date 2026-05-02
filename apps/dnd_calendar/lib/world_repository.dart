import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/world.dart';

class WorldRepository {
  WorldRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _worlds =>
      _db.collection('worlds');

  /// Worlds owned by [uid].
  ///
  /// Member-of-but-not-owner worlds will land in S4 once the `members`
  /// subcollection exists.
  Stream<List<World>> watchWorldsForUser(String uid) {
    return _worlds
        .where('ownerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(World.fromFirestore).toList());
  }

  Stream<World?> watchWorld(String worldId) {
    return _worlds.doc(worldId).snapshots().map(
          (doc) => doc.exists ? World.fromFirestore(doc) : null,
        );
  }

  /// Create a new world owned by [uid] with the supplied name and a default
  /// calendar config. Returns the new world's id.
  Future<String> createWorld({required String uid, required String name}) async {
    final doc = _worlds.doc();
    final world = World(
      id: doc.id,
      ownerUid: uid,
      name: name.trim(),
      joinCode: _generateJoinCode(),
      calendar: defaultCalendar(),
      createdAt: null, // server timestamp written below
    );
    await doc.set({
      ...world.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Replace the calendar config of one world. Owner-only — Firestore rules
  /// enforce. The `currentDate` field is part of [calendar].
  Future<void> updateCalendar(
    String worldId,
    CalendarConfigData calendar,
  ) async {
    await _worlds.doc(worldId).update({
      'calendar': calendar.toJson(),
    });
  }

  static const _joinCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _rng = Random.secure();

  /// 6-character alphanumeric code (omits visually ambiguous chars: 0/O, 1/I).
  /// Uniqueness is best-effort here; S4 hardens via a Firestore rule.
  static String _generateJoinCode() {
    return List.generate(
      6,
      (_) => _joinCodeAlphabet[_rng.nextInt(_joinCodeAlphabet.length)],
    ).join();
  }
}
