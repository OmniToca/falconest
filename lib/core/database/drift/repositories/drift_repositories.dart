/// Re-export Drift repozitářů pro snadný import.
///
/// Použij: import 'package:falconest/core/database/drift/repositories/drift_repositories.dart';
///
/// Paralelní implementace pro plný přechod na offline-first relační databázi.
/// Důvod: Isar 3.x na iOS vykazuje nestabilitu. SQLite zajišťuje 100 % běh.
library;

export 'drift_apartment_repository.dart';
export 'drift_client_repository.dart';
export 'drift_message_template_repository.dart';
export 'drift_pending_mutation_repository.dart';
export 'drift_reservation_repository.dart';
export 'drift_task_repository.dart';
export 'drift_tenant_repository.dart';
