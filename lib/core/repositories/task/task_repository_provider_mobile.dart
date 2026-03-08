import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';

/// Mobilní provider pro TaskRepository – vrací Drift (SQLite) implementaci.
///
/// PŘEPOJENÍ NA DRIFT: Repozitář je nyní napojen na stabilní SQLite (Drift) místo Isar.
/// Důvod: zajištění 100 % offline běhu na iOS bez výpadků ("Collection id is invalid").
/// Původní Isar TaskRepositoryMobile zůstává v kódu jako bezpečnostní pojistka.
final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return ref.watch(driftTaskRepositoryProvider);
});
