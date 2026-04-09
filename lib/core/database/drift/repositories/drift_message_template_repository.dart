import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:falconest_drift/app_database.dart' as db;

import 'package:falconest/core/database/models/message_template_local.dart';
import 'package:falconest/core/database/models/sync_status.dart';

/// Drift repozitář pro šablony zpráv – ekvivalent Isar MessageTemplateLocal.
///
/// Paralelní implementace pro plný přechod na offline-first relační databázi.
/// Důvod: Isar 3.x na iOS vykazuje nestabilitu. SQLite zajišťuje 100 % běh.
///
/// Worker UI čte šablony pro odesílání zpráv v terénu bez připojení.
class DriftMessageTemplateRepository {
  DriftMessageTemplateRepository(this._db);

  final db.AppDatabase _db;

  /// Načte všechny šablony tenanta, seřazené podle [orderIndex].
  Future<List<MessageTemplateLocal>> getAllByTenantId(
    String tenantId, {
    String? triggerContext,
  }) async {
    if (tenantId.trim().isEmpty) return [];

    final query = _db.select(_db.messageTemplates)
      ..where((t) {
        final tenantMatch = t.tenantId.equals(tenantId);
        if (triggerContext != null && triggerContext.trim().isNotEmpty) {
          return tenantMatch & t.triggerContext.equals(triggerContext);
        }
        return tenantMatch;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);

    final rows = await query.get();
    return rows.map(_toMessageTemplateLocal).toList();
  }

  /// Sleduje šablony tenanta pro real-time UI (např. StreamProvider).
  Stream<List<MessageTemplateLocal>> watchAllByTenantId(
    String tenantId, {
    String? triggerContext,
  }) {
    final query = _db.select(_db.messageTemplates)
      ..where((t) {
        final tenantMatch = t.tenantId.equals(tenantId);
        if (triggerContext != null && triggerContext.trim().isNotEmpty) {
          return tenantMatch & t.triggerContext.equals(triggerContext);
        }
        return tenantMatch;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);

    return query.watch().map(
          (rows) => rows.map(_toMessageTemplateLocal).toList(),
        );
  }

  /// Smaže všechny šablony tenanta. Používá se před Full Replace při sync.
  Future<int> clearForTenant(String tenantId) async {
    return (_db.delete(_db.messageTemplates)
          ..where((t) => t.tenantId.equals(tenantId)))
        .go();
  }

  /// Uloží nebo aktualizuje šablonu z mapy ze Supabase (sync).
  Future<void> upsertFromSupabaseMap(Map<String, dynamic> map) async {
    final supabaseId = map['id']?.toString().trim();
    if (supabaseId == null || supabaseId.isEmpty) return;

    final tenantId = (map['tenant_id']?.toString() ?? '').trim();
    if (tenantId.isEmpty) return;

    final existing = await (_db.select(_db.messageTemplates)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.supabaseId.equals(supabaseId)))
        .get();

    final key = (map['key']?.toString() ?? '').trim();
    final name = (map['name']?.toString() ?? '').trim();
    final channel = (map['channel'] as String?)?.trim();
    final emailSubject = (map['email_subject'] as String?)?.trim();
    final trRaw = map['translations'];
    String? translationsJson;
    if (trRaw != null) {
      try {
        if (trRaw is String) {
          final s = trRaw.trim();
          translationsJson = s.isEmpty ? null : s;
        } else {
          translationsJson = jsonEncode(trRaw);
        }
      } catch (_) {
        translationsJson = null;
      }
    }
    final triggerContext = (map['trigger_context'] as String?)?.trim();
    var orderIndex = 0;
    final rawOrder = map['order_index'];
    if (rawOrder != null) {
      if (rawOrder is int) {
        orderIndex = rawOrder;
      } else if (rawOrder is num) {
        orderIndex = rawOrder.toInt();
      }
    }
    const syncStatus = 0; // synced
    final lastSyncedAt = DateTime.now().toUtc();

    if (existing.isNotEmpty) {
      await _db.update(_db.messageTemplates).replace(
            db.MessageTemplate(
              id: existing.first.id,
              supabaseId: supabaseId,
              tenantId: tenantId,
              key: key,
              name: name,
              channel: (channel != null && channel.isNotEmpty) ? channel : null,
              emailSubject:
                  (emailSubject != null && emailSubject.isNotEmpty) ? emailSubject : null,
              translationsJson: translationsJson,
              triggerContext: (triggerContext != null && triggerContext.isNotEmpty)
                  ? triggerContext
                  : null,
              orderIndex: orderIndex,
              syncStatus: syncStatus,
              lastSyncedAt: lastSyncedAt,
            ),
          );
    } else {
      await _db.into(_db.messageTemplates).insert(
            db.MessageTemplatesCompanion.insert(
              tenantId: tenantId,
              supabaseId: Value(supabaseId),
              key: Value(key),
              name: Value(name),
              channel: Value((channel != null && channel.isNotEmpty) ? channel : null),
              emailSubject: Value(
                (emailSubject != null && emailSubject.isNotEmpty) ? emailSubject : null,
              ),
              translationsJson: Value(translationsJson),
              triggerContext: Value((triggerContext != null &&
                      triggerContext.isNotEmpty)
                  ? triggerContext
                  : null),
              orderIndex: Value(orderIndex),
              syncStatus: Value(syncStatus),
              lastSyncedAt: Value(lastSyncedAt),
            ),
          );
    }
  }

  static MessageTemplateLocal _toMessageTemplateLocal(db.MessageTemplate row) {
    return MessageTemplateLocal()
      ..supabaseId = row.supabaseId
      ..tenantId = row.tenantId
      ..key = row.key
      ..name = row.name
      ..channel = row.channel
      ..emailSubject = row.emailSubject
      ..translationsJson = row.translationsJson
      ..triggerContext = row.triggerContext
      ..orderIndex = row.orderIndex
      ..syncStatus = row.syncStatus == 1 ? SyncStatus.pending : SyncStatus.synced
      ..lastSyncedAt = row.lastSyncedAt;
  }
}
