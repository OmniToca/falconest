import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/services/owner_portal_view_sessions_repository.dart';

/// Provider repozitáře pro audit náhledu Owner portálu ([owner_portal_view_sessions]).
///
/// PROČ: AuthNotifier potřebuje při startOwnerView vytvořit záznam a při stopOwnerView
/// ho uzavřít. Repozitář je injektován stejným vzorem jako [supportInterventionsRepositoryProvider].
final ownerPortalViewSessionsRepositoryProvider =
    Provider<OwnerPortalViewSessionsRepository>(
  (ref) => OwnerPortalViewSessionsRepository(),
);
