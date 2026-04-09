import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:falconest/core/database/drift/repositories/drift_pending_mutation_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_task_checklist_repository.dart';
import 'package:falconest/core/database/drift/repositories/drift_task_repository.dart';
import 'package:falconest/core/offline/offline_checklist_photo_processor.dart';
import 'package:falconest/core/offline/mutation_queue_interface.dart';
import 'package:falconest/core/offline/pending_mutation_list_item.dart';
import 'package:falconest/core/offline/offline_cash_collection_processor.dart';
import 'package:falconest/core/offline/offline_company_expense_processor.dart';
import 'package:falconest/core/offline/offline_issue_task_processor.dart'
    show processOfflineIssueTask, ProcessIssueTaskException;
import 'package:falconest/core/offline/mutation_queue_exceptions.dart';
import 'package:falconest/core/offline/offline_photo_task_processor.dart';
import 'package:falconest/core/services/absence_notification_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Drift implementace fronty mutací – zapisuje do SQLite místo Isar.
///
/// PŘEPOJENÍ NA DRIFT: Repozitář je nyní napojen na stabilní SQLite (Drift).
/// Důvod: zajištění 100 % offline běhu na iOS bez výpadků ("Collection id is invalid").
/// Původní Isar MutationQueueService zůstává v kódu jako bezpečnostní pojistka.
class DriftMutationQueueService implements MutationQueueServiceInterface {
  DriftMutationQueueService(
    this._repo, [
    this._taskRepo,
    this._checklistRepo,
  ]);

  final DriftPendingMutationRepository _repo;
  final DriftTaskRepository? _taskRepo;
  /// PROČ: Upload fotek checklistu potřebuje po úspěchu zapsat Drift – stejná vrstva jako u úkolů.
  final DriftTaskChecklistRepository? _checklistRepo;

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
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DriftMutationQueueService.enqueueMutation ERROR: $e');
        debugPrint('$st');
      }
      // PROČ: Volající musí vědět, že zápis do fronty selhal – jinak by uživatel ztratil data bez zpětné vazby.
      rethrow;
    }
  }

  @override
  Future<void> processQueue() async {
    final pending = await _repo.getAllOrderedByCreatedAt();

    for (final m in pending) {
      try {
        final payload = m.payload;
        if (payload == null || payload.isEmpty) {
          // PROČ: Prázdná mutace se nesmí tiše smazat – zůstane ve frontě pro diagnostiku / opravu dat.
          throw EmptyQueuedMutationPayloadException('mutation id=${m.id}');
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
          case 'UPLOAD_CHECKLIST_PHOTO':
            await processUploadChecklistPhoto(
              payload,
              checklistRepo: _checklistRepo,
            );
            break;
          case 'INSERT':
            final insertTid = payload['tenant_id']?.toString();
            if (insertTid != null && insertTid.isNotEmpty) {
              // Bezpečnostní vynucení tenant_id klauzule přes safeFrom (payload + insert scope).
              await SupabaseService.safeFrom(m.tableName, insertTid).insert(
                    Map<String, dynamic>.from(payload),
                  );
            } else {
              throw MissingQueuedMutationTenantIdException(
                tableName: m.tableName,
                action: m.actionType,
              );
            }
            // Po úspěšném odeslání absence z fronty notifikujeme adminy (zvoneček).
            if (m.tableName == 'staff_absences') {
              try {
                await AbsenceNotificationService.notifyAdminsAboutAbsenceFromPayload(payload);
              } catch (e, st) {
                AppLogger.error('DriftMutationQueueService: notifikace adminů po INSERT staff_absences z fronty selhala', e, st);
              }
            }
            break;
          case 'UPDATE':
            if (m.recordId == null || m.recordId!.isEmpty) {
              throw MissingRecordIdException(actionType: m.actionType, tableName: m.tableName);
            }
            final updateTid = payload['tenant_id']?.toString();
            if (updateTid != null && updateTid.isNotEmpty) {
              await SupabaseService.safeFrom(m.tableName, updateTid)
                  .update(Map<String, dynamic>.from(payload))
                  .eq('id', m.recordId!);
            } else {
              throw MissingQueuedMutationTenantIdException(
                tableName: m.tableName,
                action: m.actionType,
              );
            }
            break;
          // PROČ: Worker checklist používá vlastní action pro čitelnost fronty; chování je shodné s UPDATE.
          case 'UPDATE_CHECKLIST_ITEM':
            if (m.recordId == null || m.recordId!.isEmpty) {
              throw MissingRecordIdException(actionType: m.actionType, tableName: m.tableName);
            }
            final checklistUpdateTid = payload['tenant_id']?.toString();
            if (checklistUpdateTid != null && checklistUpdateTid.isNotEmpty) {
              await SupabaseService.safeFrom(m.tableName, checklistUpdateTid)
                  .update(Map<String, dynamic>.from(payload))
                  .eq('id', m.recordId!);
            } else {
              throw MissingQueuedMutationTenantIdException(
                tableName: m.tableName,
                action: m.actionType,
              );
            }
            break;
          case 'DELETE':
            if (m.recordId == null || m.recordId!.isEmpty) {
              throw MissingRecordIdException(actionType: m.actionType, tableName: m.tableName);
            }
            final deleteTid = payload['tenant_id']?.toString();
            if (deleteTid != null && deleteTid.isNotEmpty) {
              await SupabaseService.safeFrom(m.tableName, deleteTid)
                  .delete()
                  .eq('id', m.recordId!);
            } else {
              throw MissingQueuedMutationTenantIdException(
                tableName: m.tableName,
                action: m.actionType,
              );
            }
            break;
          default:
            throw UnknownMutationTypeException(m.actionType);
        }

        // PROČ: Mazat řádek fronty jen po prokazatelně úspěšném dokončení větve výše.
        await _repo.deleteById(m.id);
      } catch (e, st) {
        // Síťové chyby nebo 5xx = zastavíme celé zpracování; mutace zůstávají (včetně aktuální).
        if (DriftMutationQueueService.isRetryableError(e)) {
          if (kDebugMode) {
            debugPrint('DriftMutationQueueService.processQueue: retryable error, stopping: $e');
          }
          return;
        }
        // PROČ: Jiné chyby (neplatný payload, 4xx, neznámý typ…) – mutaci NEMAŽEME; pokračujeme další položkou.
        if (kDebugMode) {
          debugPrint('DriftMutationQueueService.processQueue: keeping mutation in queue: $e');
          debugPrint('$st');
        }
      }
    }
  }

  @override
  Future<int> getPendingCount() async {
    return _repo.getCount();
  }

  @override
  Future<List<PendingMutationListItem>> getPendingMutations() async {
    final rows = await _repo.getAllOrderedByCreatedAt();
    return rows.map(PendingMutationListItem.fromRow).toList();
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
