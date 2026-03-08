import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/drift/app_database.dart';
import 'package:falconest/core/database/drift/repositories/drift_apartment_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_client_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_message_template_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_pending_mutation_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_reservation_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_task_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_tenant_repository.dart';

/// Provider pro Drift (SQLite) databázi – paralelní implementace pro 100 % offline stabilitu.
///
/// PROČ DRIFT: Isar 3.x na starších iOS vykazuje fatální chyby ("Collection id is invalid").
/// SQLite je průmyslový standard s garantovanou stabilitou na všech platformách.
/// Tento provider vrací jedinou instanci AppDatabase pro celou aplikaci.
///
/// POZNÁMKA: Importován pouze z mobilních souborů (dart:io) – web tento modul nepoužívá.
final driftDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Provider pro Drift frontu pending mutací.
///
/// Používá se v MutationQueueService (Drift verze) a v DriftTaskRepository pro enqueue
/// při offline ukládání fotek (OFFLINE_TASK_COMPLETE_WITH_PHOTOS).
final driftPendingMutationRepositoryProvider =
    Provider<DriftPendingMutationRepository>((ref) {
  final db = ref.watch(driftDatabaseProvider);
  return DriftPendingMutationRepository(db);
});

/// Provider pro Drift repozitář apartmánů – lookup pro Worker úkoly.
final driftApartmentRepositoryProvider =
    Provider<DriftApartmentRepository>((ref) {
  final db = ref.watch(driftDatabaseProvider);
  return DriftApartmentRepository(db);
});

/// Provider pro Drift repozitář klientů – lookup pro Worker úkoly (externí transfer).
final driftClientRepositoryProvider = Provider<DriftClientRepository>((ref) {
  final db = ref.watch(driftDatabaseProvider);
  return DriftClientRepository(db);
});

/// Provider pro Drift repozitář rezervací – lookup guest_name/guest_phone pro check-in.
final driftReservationRepositoryProvider =
    Provider<DriftReservationRepository>((ref) {
  final db = ref.watch(driftDatabaseProvider);
  return DriftReservationRepository(db);
});

/// Provider pro Drift repozitář tenantů – měna tenanta pro offline formátování hotovosti.
final driftTenantRepositoryProvider = Provider<DriftTenantRepository>((ref) {
  final db = ref.watch(driftDatabaseProvider);
  return DriftTenantRepository(db);
});

/// Provider pro Drift repozitář šablon zpráv – Worker čte šablony v terénu offline.
final driftMessageTemplateRepositoryProvider =
    Provider<DriftMessageTemplateRepository>((ref) {
  final db = ref.watch(driftDatabaseProvider);
  return DriftMessageTemplateRepository(db);
});

/// Svazek Drift repozitářů pro WorkerSyncService – paralelní zápis při sync.
///
/// PROČ: WorkerSyncService stahuje z Supabase a zapisuje do Isaru. Pro plný přechod
/// na SQLite zapisujeme data paralelně i do Driftu, aby Worker UI měl plný offline
/// kontext (adresy, keyboxy, jména klientů, hostů, měna).
class DriftSyncRepos {
  DriftSyncRepos({
    required this.task,
    required this.apartment,
    required this.client,
    required this.reservation,
    required this.tenant,
    required this.messageTemplate,
  });

  final DriftTaskRepository task;
  final DriftApartmentRepository apartment;
  final DriftClientRepository client;
  final DriftReservationRepository reservation;
  final DriftTenantRepository tenant;
  final DriftMessageTemplateRepository messageTemplate;
}

/// Provider pro DriftSyncRepos – injektuje se do WorkerSyncService při sync.
final driftSyncReposProvider = Provider<DriftSyncRepos>((ref) {
  return DriftSyncRepos(
    task: ref.watch(driftTaskRepositoryProvider),
    apartment: ref.watch(driftApartmentRepositoryProvider),
    client: ref.watch(driftClientRepositoryProvider),
    reservation: ref.watch(driftReservationRepositoryProvider),
    tenant: ref.watch(driftTenantRepositoryProvider),
    messageTemplate: ref.watch(driftMessageTemplateRepositoryProvider),
  );
});

/// Provider pro Drift repozitář úkolů – implementuje ITaskRepository.
///
/// Nahrazuje Isar TaskRepositoryMobile. Aplikační logika (UI) nyní čte/zapisuje ze SQLite,
/// což zajišťuje 100 % offline běh na iOS bez výpadků.
///
/// Apartments, Clients, Reservations repozitáře obohacují WorkerTask o jména/adresy.
final driftTaskRepositoryProvider = Provider<DriftTaskRepository>((ref) {
  final db = ref.watch(driftDatabaseProvider);
  final pendingRepo = ref.watch(driftPendingMutationRepositoryProvider);
  final apartmentRepo = ref.watch(driftApartmentRepositoryProvider);
  final clientRepo = ref.watch(driftClientRepositoryProvider);
  final reservationRepo = ref.watch(driftReservationRepositoryProvider);
  return DriftTaskRepository(
    db,
    pendingRepo,
    apartmentRepo,
    clientRepo,
    reservationRepo,
  );
});
