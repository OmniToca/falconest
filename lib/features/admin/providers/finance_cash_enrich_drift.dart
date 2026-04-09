import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest_drift/app_database.dart' as drift_db;

/// Obohacení transakcí peněženky z lokální Drift DB (úkoly, byty, rezervace, klienti).
///
/// PROČ: Worker na mobilu nesmí kvůli historii peněženky dotazovat Supabase; kontext bereme
/// z dat, která už máme po worker sync (tasks, apartments, reservations, clients).
/// POZNÁMKA: Lokální [drift_db.Client] nemusí mít `client_type` (úzký subset) – typ klienta
/// v offline režimu může chybět; UI zobrazí alespoň jméno.
Future<List<CashTransactionUIModel>> enrichCashTransactionsFromDrift(
  Ref ref,
  String tenantId,
  List<Map<String, dynamic>> rows,
) async {
  if (rows.isEmpty) return [];

  final taskRepo = ref.read(driftTaskRepositoryProvider);
  final clientRepo = ref.read(driftClientRepositoryProvider);

  final taskDetailCache = <String, WorkerTaskDetail?>{};

  Future<void> ensureTaskDetail(String taskId) async {
    if (taskDetailCache.containsKey(taskId)) return;
    taskDetailCache[taskId] = await taskRepo.getWorkerTaskDetail(tenantId, taskId);
  }

  final clientCache = <String, drift_db.Client?>{};

  Future<void> ensureClient(String clientId) async {
    if (clientCache.containsKey(clientId)) return;
    clientCache[clientId] = await clientRepo.getBySupabaseId(tenantId, clientId);
  }

  for (final r in rows) {
    final tid = (r['task_id'] as String?)?.trim();
    if (tid != null && tid.isNotEmpty) await ensureTaskDetail(tid);
    final cid = (r['client_id'] as String?)?.trim();
    if (cid != null && cid.isNotEmpty) await ensureClient(cid);
  }

  return rows.map((r) {
    final taskId = (r['task_id'] as String?)?.trim();
    final clientId = (r['client_id'] as String?)?.trim();

    String? apartmentName;
    String? guestName;
    String? taskTitle;
    if (taskId != null && taskId.isNotEmpty) {
      final detail = taskDetailCache[taskId];
      if (detail != null) {
        apartmentName = detail.apartmentName;
        guestName = detail.guestName;
        taskTitle = detail.title;
      }
    }

    String? clientName;
    if (clientId != null && clientId.isNotEmpty) {
      final c = clientCache[clientId];
      if (c != null) {
        final name = c.name.trim();
        clientName = name.isNotEmpty ? name : null;
      }
    }

    return CashTransactionUIModel(
      raw: Map<String, dynamic>.from(r),
      apartmentName: apartmentName,
      guestName: guestName,
      taskTitle: taskTitle,
      clientName: clientName,
      clientType: null,
    );
  }).toList();
}
