/// Mobilní export getTaskRepository – používá taskRepositoryProvider (Drift).
///
/// Isar odstraněn. getTaskRepository() není používán – vše jde přes taskRepositoryProvider.
/// Pro zpětnou kompatibilitu exportu vracíme UnsupportedError.
import 'package:falconest/core/repositories/task/task_repository.dart';

ITaskRepository getTaskRepository() => throw UnsupportedError(
      'Použij taskRepositoryProvider – getTaskRepository() je deprecated.',
    );
