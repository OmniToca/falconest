import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:falconest/core/database/drift/repositories/drift_pending_mutation_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_task_repository.dart';
import 'package:falconest/core/offline/mutation_queue_interface.dart';
import 'package:falconest/core/offline/offline_cash_collection_processor.dart';
import 'package:falconest/core/offline/offline_company_expense_processor.dart';
import 'package:falconest/core/offline/offline_issue_task_processor.dart'
    show processOfflineIssueTask, ProcessIssueTaskException;
import 'package:falconest/core/offline/offline_photo_task_processor.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Drift implementace fronty mutací – zapisuje do SQLite místo Isar.
///
/// PŘEPOJENÍ NA DRIFT: Repozitář je nyní napojen na stabilní SQLite (Drift).
/// Důvod: zajištění 100 % offline běhu na iOS bez výpadků ("Collection id is invalid").
/// Původní Isar MutationQueueService zůstává v kódu jako bezpečnostní pojistka.
class DriftMutationQueueService implements MutationQueueServiceInterface {
  DriftMutationQueueService(this._repo, [this._taskRepo]);

  final DriftPendingMutationRepository _repo;
  final DriftTaskRepository? _taskRepo;

  @override
  Future<void> enqueueMutation({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
    String? recordId,
  }) async {
    try {
      await _repo.enqueue(
        table: table,
        action: action,
        payload: payload,
        recordId: recordId,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('DriftMutationQueueService.enqueueMutation ERROR: $e');
      }
    }
  }

  @override
  Future<void> processQueue() async {
    final pending = await _repo.getAllOrderedByCreatedAt();

    for (final m in pending) {
      try {
        final payload = m.payload;
        if (payload == null || payload.isEmpty) {
          await _repo.deleteById(m.id);
          continue;
        }

        switch (m.actionType.toUpperCase()) {
          case 'OFFLINE_CASH_COLLECTION':
            await processOfflineCashCollection(payload);
            break;
          case 'OFFLINE_COMPANY_EXPENSE':
            await processOfflineCompanyExpense(payload);
            break;
          case 'OFFLINE_ISSUE_TASK':
            await processOfflineIssueTask(payload);
            break;
          case 'OFFLINE_TASK_COMPLETE_WITH_PHOTOS':
            await processOfflineTaskCompleteWithPhotos(payload, driftTaskRepository: _taskRepo);
            break;
          case 'INSERT':
            await SupabaseService.client.from(m.tableName).insert(payload);
            break;
          case 'UPDATE':
            if (m.recordId == null || m.recordId!.isEmpty) continue;
            var updateQuery = SupabaseService.client
                .from(m.tableName)
                .update(payload)
                .eq('id', m.recordId!);
            final tenantId = payload['tenant_id']?.toString();
            if (tenantId != null && tenantId.isNotEmpty) {
              updateQuery = updateQuery.eq('tenant_id', tenantId);
            }
            await updateQuery;
            break;
          case 'DELETE':
            if (m.recordId == null || m.recordId!.isEmpty) continue;
            var deleteQuery = SupabaseService.client
                .from(m.tableName)
                .delete()
                .eq('id', m.recordId!);
            final tenantId = payload['tenant_id']?.toString();
            if (tenantId != null && tenantId.isNotEmpty) {
              deleteQuery = deleteQuery.eq('tenant_id', tenantId);
            }
            await deleteQuery;
            break;
          default:
            continue;
        }

        await _repo.deleteById(m.id);
      } catch (e) {
        // Síťové chyby nebo 5xx z Edge Function = mutace zůstane ve frontě k opakování
        if (DriftMutationQueueService.isRetryableError(e)) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('DriftMutationQueueService.processQueue: retryable error, stopping: $e');
          }
          return;
        }
        if (kDebugMode) {
          // ignore: avoid_print
          print('DriftMutationQueueService.processQueue: non-retryable error, removing: $e');
        }
        await _repo.deleteById(m.id);
      }
    }
  }

  @override
  Future<int> getPendingCount() async {
    return _repo.getCount();
  }

  /// Rozpozná síťovou chybu – shodná logika jako MutationQueueService.isNetworkError.
  static bool isNetworkError(Object e) {
    final type = e.runtimeType.toString();
    if (type.contains('SocketException')) return true;
    if (type.contains('TimeoutException')) return true;
    if (type.contains('ClientException')) return true;
    if (type.contains('HandshakeException')) return true;
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('network') ||
        msg.contains('timeout')) {
      return true;
    }
    return false;
  }

  /// Rozpozná chybu, u které má mutace zůstat ve frontě (síť + 5xx).
  /// PROČ: Edge Function process-issue-ai může vrátit 5xx při výpadku DB –
  /// úkol se nesmí ztratit, musíme ho zkusit znovu po obnovení.
  static bool isRetryableError(Object e) {
    if (isNetworkError(e)) return true;
    // ProcessIssueTaskException s 5xx
    if (e is ProcessIssueTaskException && e.isRetryable) return true;
    final msg = e.toString().toLowerCase();
    // Obecné 5xx v chybové zprávě (FunctionsException atd.)
    if (msg.contains('status=500') ||
        msg.contains('status=502') ||
        msg.contains('status=503') ||
        msg.contains('status=504')) {
      return true;
    }
    return false;
  }
}
