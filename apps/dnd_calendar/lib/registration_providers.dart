import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/registration.dart';
import 'registration_repository.dart';
import 'world_providers.dart';

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => RegistrationRepository(ref.watch(firestoreProvider)),
);

final registrationsProvider = StreamProvider.family<List<Registration>,
    ({String worldId, String eventId})>(
  (ref, k) => ref
      .watch(registrationRepositoryProvider)
      .watchRegistrations(k.worldId, k.eventId),
);
