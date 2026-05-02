import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/member.dart';
import 'models/world.dart';

class WorldRepository {
  WorldRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _worlds =>
      _db.collection('worlds');

  CollectionReference<Map<String, dynamic>> get _joinCodes =>
      _db.collection('joinCodes');

  /// Worlds owned by [uid].
  Stream<List<World>> watchOwnedWorlds(String uid) {
    return _worlds
        .where('ownerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(World.fromFirestore).toList());
  }

  /// World ids that [uid] joined as a player. Uses a collectionGroup query
  /// over every `members` subcollection in the database, filtered by `uid`
  /// (which we mirror onto each member doc for query support).
  Stream<List<String>> watchJoinedWorldIds(String uid) {
    return _db
        .collectionGroup('members')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final ids = <String>[];
      for (final d in snap.docs) {
        // Path: worlds/{worldId}/members/{uid}
        final parts = d.reference.path.split('/');
        final worldsIdx = parts.indexOf('worlds');
        if (worldsIdx >= 0 && worldsIdx + 1 < parts.length) {
          ids.add(parts[worldsIdx + 1]);
        }
      }
      return ids;
    });
  }

  /// Resolve a join code to its world id (or null). Reads from the
  /// `joinCodes` side-collection so the lookup doesn't require read access
  /// on the world doc itself.
  Future<String?> resolveJoinCode(String code) async {
    final doc = await _joinCodes.doc(code.toUpperCase().trim()).get();
    if (!doc.exists) return null;
    return doc.data()?['worldId'] as String?;
  }

  Future<World?> getWorld(String worldId) async {
    final doc = await _worlds.doc(worldId).get();
    return doc.exists ? World.fromFirestore(doc) : null;
  }

  /// Self-join: writes `worlds/{worldId}/members/{uid}` with role=player.
  /// Idempotent (re-joining is a no-op).
  Future<void> joinWorld({required String worldId, required String uid}) async {
    await _worlds
        .doc(worldId)
        .collection('members')
        .doc(uid)
        .set({
      'uid': uid,
      'role': MemberRole.player.name,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<World?> watchWorld(String worldId) {
    return _worlds.doc(worldId).snapshots().map(
          (doc) => doc.exists ? World.fromFirestore(doc) : null,
        );
  }

  /// Create a new world owned by [uid] with the supplied name and a default
  /// calendar config. Writes the world doc and a sibling `joinCodes/{code}`
  /// pointer in a single batch so the join-by-code flow can resolve a code
  /// without needing read access on every world doc.
  ///
  /// Retries on join-code collision (up to 5 attempts).
  Future<String> createWorld({required String uid, required String name}) async {
    var attempts = 0;
    while (true) {
      attempts += 1;
      final doc = _worlds.doc();
      final code = _generateJoinCode();
      final world = World(
        id: doc.id,
        ownerUid: uid,
        name: name.trim(),
        joinCode: code,
        calendar: defaultCalendar(),
        createdAt: null,
      );
      try {
        final batch = _db.batch();
        batch.set(doc, {
          ...world.toFirestore(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(_joinCodes.doc(code), {
          'worldId': doc.id,
          'ownerUid': uid,
        });
        await batch.commit();
        return doc.id;
      } on FirebaseException catch (e) {
        // Collision on joinCodes (already-exists) → retry with a fresh code.
        if (attempts >= 5 || e.code != 'already-exists') rethrow;
      }
    }
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
