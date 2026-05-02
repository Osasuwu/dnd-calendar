import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'event_repository.dart';
import 'models/event.dart';
import 'world_providers.dart';

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(firestoreProvider)),
);

/// Stream of all events for a world, ordered by startDate ascending.
final eventsProvider = StreamProvider.family<List<Event>, String>((ref, worldId) {
  return ref.watch(eventRepositoryProvider).watchEvents(worldId);
});

/// One event by id.
final eventProvider =
    StreamProvider.family<Event?, ({String worldId, String eventId})>(
  (ref, k) =>
      ref.watch(eventRepositoryProvider).watchEvent(k.worldId, k.eventId),
);
