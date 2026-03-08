import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/drift/database_provider.dart';

/// Mobilní: vrací DriftSyncRepos pro paralelní zápis při sync.
/// Obsahuje task, apartment, client, reservation, tenant, messageTemplate.
DriftSyncRepos? getDriftReposForSync(Ref ref) =>
    ref.read(driftSyncReposProvider);
