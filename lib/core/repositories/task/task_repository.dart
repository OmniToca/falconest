/// Abstraktní rozhraní pro repozitář úkolů – Clean Architecture.
///
/// Odděluje datovou vrstvu od UI. Na webu implementace čte ze Supabase,
/// na mobilu z lokální Drift databáze (offline-first).
/// Doménové modely [WorkerTask] / [WorkerTaskDetail] nemají závislost na úložišti.
library;

import 'package:falconest/core/models/worker_task.dart';
import 'package:falconest/core/models/worker_task_detail.dart';

export 'package:falconest/core/models/worker_task.dart';
export 'package:falconest/core/models/worker_task_detail.dart';

/// Repozitář pro čtení úkolů přiřazených pracovníkovi.
///
/// Implementace se vybírá podmíněným importem (web vs. mobil).
abstract class ITaskRepository {
  /// Načte úkoly přiřazené pracovníkovi. Vynechá completed.
  Future<List<WorkerTask>> getWorkerTasks(String tenantId, String workerId);

  /// Načte detail úkolu podle Supabase UUID.
  Future<WorkerTaskDetail?> getWorkerTaskDetail(String tenantId, String taskId);

  /// Aktualizuje status úkolu (offline: pending, pak sync).
  /// [startedAt] – nastaví se při přechodu do in_progress (Time Tracking).
  /// [completedAt] – nastaví se při přechodu do completed (Time Tracking).
  /// [metadataOverlay] – volitelně sloučí dodatečné klíče do metadata (např. cash_collection_failed).
  /// [mediaUrls] – URL fotek z Supabase Storage (např. pro úkoly s requires_photo). Nahrání volá klient před voláním.
  /// [localPhotoPaths] – cesty k lokálním souborům při offline (zkopírované do persistent storage).
  /// [existingMediaUrls] – již nahrané URL při offline flow (pro merge v procesoru).
  /// Na webu ignorováno. Na mobilu: enqueue OFFLINE_TASK_COMPLETE_WITH_PHOTOS, aktualizuje Drift.
  Future<void> updateTaskStatus(
    String tenantId,
    String taskId,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadataOverlay,
    List<String>? mediaUrls,
    List<String>? localPhotoPaths,
    List<String>? existingMediaUrls,
  });

  /// Připojí jeden řádek textu k `tasks.description` (rychlá poznámka z terénu).
  ///
  /// PROČ: Worker nepřepisuje popis — jen append s časem/jménem z UI; offline Drift + fronta UPDATE.
  Future<void> appendWorkerQuickNote(
    String tenantId,
    String taskId,
    String appendedLine,
  );
}

/// Agregace dokončených úkolů v aktuálním kalendářním týdnu (pro drawer / Drift watch).
///
/// PROČ: Oddělený DTO od feature vrstvy – [DriftTaskRepository.watchWeeklyCompletedTaskStats] vrací čistá data.
class WorkerWeekTaskStats {
  const WorkerWeekTaskStats({
    required this.totalTasks,
    required this.totalEstimatedMinutes,
  });

  final int totalTasks;
  final int totalEstimatedMinutes;

  double get totalHours => totalEstimatedMinutes / 60.0;
}

/// Měsíční motivační metriky workera (dokončené úkoly v aktuálním kalendářním měsíci, lokální čas).
///
/// PROČ: Dashboard skrývá hotové úkoly – tento DTO čte `completed_at` / `started_at` z Driftu nebo Supabase
/// pro povzbudivý přehled „plodů práce“ bez rozšiřování modelu [WorkerTask].
class WorkerMonthMotivationStats {
  const WorkerMonthMotivationStats({
    required this.completedCount,
    required this.workedHours,
    required this.onTimeCount,
    required this.onTimeEligibleCount,
  });

  /// Počet úkolů se statusem dokončeno a `completed_at` v aktuálním měsíci.
  final int completedCount;

  /// Součet (completed_at − started_at) v hodinách u záznamů s oběma časovými razítky (0–16 h na úkol).
  final double workedHours;

  /// Dokončení ve **stejný kalendářní den** jako plánovaný začátek (lokální čas) – jednoduchá „včasnost“.
  final int onTimeCount;

  /// Počet dokončených v měsíci s platným `scheduled_start` (měřitelná včasnost).
  final int onTimeEligibleCount;

  double? get onTimePercent =>
      onTimeEligibleCount > 0 ? (onTimeCount * 100.0 / onTimeEligibleCount) : null;
}

/// Výchozí měsíční cíl úklidů pro progress bar (UI může později číst z konfigurace tenanta).
const int kWorkerMonthlyGoalCompletedTasks = 30;
