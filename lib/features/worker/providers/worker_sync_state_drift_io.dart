import 'package:falconest/core/database/drift/database_provider.dart';

/// Mobilní: vrací DriftSyncRepos pro paralelní zápis při sync.
///
/// PROČ [dynamic]: voláno z [Ref] (StateNotifier) i z [WidgetRef] ([NetworkSyncWatcher]) –
/// oba mají [read]; sjednocený typ bez závislosti na podtypech Riverpod API.
DriftSyncRepos getDriftReposForSync(dynamic ref) =>
    ref.read(driftSyncReposProvider) as DriftSyncRepos;
