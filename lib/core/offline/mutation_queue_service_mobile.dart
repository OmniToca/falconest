import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/pending_mutation_local.dart';
import 'package:falconest/core/offline/offline_cash_collection_processor.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Mobilní implementace MutationQueueService – zapisuje do Isar, odesílá při processQueue.
///
/// Univerzální fronta pro offline operace. Admin (a budoucí moduly) sem ukládají
/// mutace při síťové chybě; NetworkSyncWatcher při návratu sítě volá processQueue.
class MutationQueueService {
  MutationQueueService._();

  static final MutationQueueService instance = MutationQueueService._();

  /// Uloží mutaci do lokální fronty (PendingMutationLocal).
  ///
  /// Volá se z Admin repozitáře při zachycení SocketException/TimeoutException –
  /// data se neztratí a čekají na odeslání po obnovení sítě.
  Future<void> enqueueMutation({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
    String? recordId,
  }) async {
    try {
      final isar = IsarService.instance;
      final mutation = PendingMutationLocal()
        ..tableName = table
        ..actionType = action
        ..payloadJson = jsonEncode(payload)
        ..recordId = recordId
        ..createdAt = DateTime.now().toUtc();
      await isar.writeTxn(() async => isar.pendingMutationLocals.put(mutation));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MutationQueueService.enqueueMutation ERROR: $e');
      }
    }
  }

  /// Načte frontu, seřadí podle createdAt a odešle do Supabase.
  ///
  /// Při síťové chybě okamžitě přeruší (zachová pořadí). Úspěšné záznamy se mažou.
  Future<void> processQueue() async {
    Isar isar;
    try {
      isar = IsarService.instance;
    } on StateError {
      return;
    }

    final pending = await isar.pendingMutationLocals
        .filter()
        .idGreaterThan(0)
        .findAll();
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final m in pending) {
      try {
        final payload = jsonDecode(m.payloadJson) as Map<String, dynamic>?;
        if (payload == null || payload.isEmpty) {
          await isar.writeTxn(() async => isar.pendingMutationLocals.delete(m.id));
          continue;
        }

        switch (m.actionType.toUpperCase()) {
          case 'OFFLINE_CASH_COLLECTION':
            await processOfflineCashCollection(payload);
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

        await isar.writeTxn(() async => isar.pendingMutationLocals.delete(m.id));
      } catch (e) {
        // Síťová chyba – přerušit a počkat na další pokus (zachovat pořadí).
        if (MutationQueueService.isNetworkError(e)) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('MutationQueueService.processQueue: network error, stopping: $e');
          }
          return;
        }
        // Jiná chyba (validace, RLS) – záznam odstranit, aby neblokoval frontu.
        if (kDebugMode) {
          // ignore: avoid_print
          print('MutationQueueService.processQueue: non-network error, removing: $e');
        }
        await isar.writeTxn(() async => isar.pendingMutationLocals.delete(m.id));
      }
    }
  }

  /// Vrací počet záznamů ve frontě (PendingMutationLocal).
  /// PROČ: Pro SyncStatusIcon – uživatel vidí, kolik změn čeká na odeslání.
  Future<int> getPendingCount() async {
    try {
      final isar = IsarService.instance;
      final pending = await isar.pendingMutationLocals
          .filter()
          .idGreaterThan(0)
          .count();
      return pending;
    } on StateError {
      return 0;
    }
  }

  /// Rozpozná, zda výjimka odpovídá síťové chybě (offline, timeout).
  /// Veřejné pro CashWalletRepository – záchrana výběru hotovosti při offline.
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
}

final mutationQueueServiceProvider = Provider<MutationQueueService>((ref) {
  return MutationQueueService.instance;
});
