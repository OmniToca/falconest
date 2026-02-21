import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

import 'package:falconest/core/database/models/pending_audit_action.dart';
import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Jeden záznam z tabulky audit_logs – pro zobrazení v modulu Odpadkový koš.
///
/// [tableName] a [recordId] určují původní entitu; u SOFT_DELETE lze obnovit
/// nastavením deleted_at = null, nebo trvale smazat (.delete()).
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    this.tenantId,
    this.userId,
    required this.actionType,
    this.tableName,
    this.recordId,
    this.details,
    required this.createdAt,
  });

  final String id;
  final String? tenantId;
  final String? userId;
  final String actionType;
  final String? tableName;
  final String? recordId;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  static AuditLogEntry? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final createdAtRaw = map['created_at'];
    DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now().toUtc();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now().toUtc();
    }
    final detailsRaw = map['details'];
    Map<String, dynamic>? details;
    if (detailsRaw is Map<String, dynamic>) {
      details = detailsRaw;
    } else if (detailsRaw is Map) {
      details = Map<String, dynamic>.from(detailsRaw);
    }
    return AuditLogEntry(
      id: id,
      tenantId: map['tenant_id']?.toString(),
      userId: map['user_id']?.toString(),
      actionType: map['action_type'] as String? ?? '',
      tableName: map['table_name'] as String?,
      recordId: map['record_id'] as String?,
      details: details,
      createdAt: createdAt,
    );
  }
}

/// Konstanty typů akcí v audit_logs – pro filtrování a zobrazení.
abstract class AuditActionType {
  static const String softDelete = 'SOFT_DELETE';
  static const String softDeleteCascade = 'SOFT_DELETE_CASCADE';
}

/// Tabulky, u kterých existuje soft delete (deleted_at) a lze obnovit / hard delete.
const Set<String> _softDeleteTables = {'apartments', 'tasks', 'profiles', 'reservations'};

/// Repository pro čtení audit_logs a provádění akcí Obnovit / Trvalé odstranění.
///
/// Offline-first: zápisové operace (restore, hard delete) jdou nejdřív do Isar
/// (PendingAuditAction) s UTC časovým razítkem; na pozadí se synchronizují do Supabase.
/// Na webu Isar neběží – tam se volá Supabase přímo, aby modul fungoval i bez lokální DB.
class AuditLogRepository {
  AuditLogRepository._();

  static final _client = SupabaseService.client;

  /// Načte pro daná user_id (z audit_logs) zobrazení jmen z tabulky profiles.
  ///
  /// DŮLEŽITÉ: V audit_logs sloupec user_id odkazuje na auth.users(id), NE na profiles.id.
  /// V profiles je auth_id = auth.users(id). Proto dotazujeme profiles podle auth_id (WHERE
  /// auth_id IN (…)), ne podle id. Jinak bychom nikdy nenašli řádek a zobrazovalo by se
  /// „Neznámý uživatel“. Super_admin má oprávnění číst profiles napříč tenanty (RLS).
  static Future<Map<String, String>> fetchActorNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final ids = userIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    try {
      final res = await _client
          .from('profiles')
          .select('auth_id, first_name, last_name, name')
          .inFilter('auth_id', ids);
      final list = res;
      final out = <String, String>{};
      for (final e in list) {
        final map = Map<String, dynamic>.from(e as Map);
        final authId = map['auth_id']?.toString().trim();
        if (authId == null || authId.isEmpty) continue;
        final first = (map['first_name']?.toString() ?? '').trim();
        final last = (map['last_name']?.toString() ?? '').trim();
        final name = (map['name']?.toString() ?? '').trim();
        final display = first.isNotEmpty || last.isNotEmpty
            ? '$first $last'.trim()
            : (name.isNotEmpty ? name : authId);
        out[authId] = display;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Načte záznamy z audit_logs. Super_admin vidí vše (RLS); volitelně lze filtrovat
  /// podle [tenantId]. Řazení od nejnovějších. Primárně pro záznamy SOFT_DELETE.
  static Future<List<AuditLogEntry>> fetchLogs({String? tenantId, int limit = 200}) async {
    try {
      dynamic query = _client
          .from('audit_logs')
          .select('id, tenant_id, user_id, action_type, table_name, record_id, details, created_at');
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }
      query = query.order('created_at', ascending: false).limit(limit);
      final res = await query;
      final list = res is List ? res : <dynamic>[];
      final out = <AuditLogEntry>[];
      for (final e in list) {
        final map = e is Map ? Map<String, dynamic>.from(e) : null;
        final entry = AuditLogEntry.fromJson(map);
        if (entry != null) out.add(entry);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// (Budoucí rozšíření) Dohledání zobrazovacího názvu entity podle table_name a record_id.
  ///
  /// Soft-deleted záznamy stále existují v DB (deleted_at IS NOT NULL). Lze tedy dotazem
  /// podle record_id na příslušnou tabulku (tasks.title, apartments.name, profiles – first_name+last_name,
  /// reservations – např. guest_name nebo id) získat lidsky čitelný název místo holého UUID.
  /// Struktura: async funkce fetchEntityDisplayName(String tableName, String recordId) → String?,
  /// volaná např. v provideru pro zobrazení v audit logu.
  static bool canRestore(AuditLogEntry entry) {
    if (entry.tableName == null || entry.recordId == null) return false;
    if (entry.actionType != AuditActionType.softDelete &&
        entry.actionType != AuditActionType.softDeleteCascade) {
      return false;
    }
    return _softDeleteTables.contains(entry.tableName);
  }

  /// Zda lze u záznamu provést trvalé odstranění (známe tabulku a record_id).
  static bool canHardDelete(AuditLogEntry entry) {
    if (entry.tableName == null || entry.recordId == null) return false;
    return _softDeleteTables.contains(entry.tableName);
  }

  /// Obnoví soft-deleted entitu: nastaví deleted_at = null v příslušné tabulce.
  /// Offline-first: na platformách s Isar se akce zapíše do PendingAuditAction s UTC časem,
  /// pak se spustí processPendingAuditActions() pro synchronizaci do Supabase. Na webu
  /// Isar neběží – volá se Supabase přímo.
  static Future<void> restore(AuditLogEntry entry) async {
    final table = entry.tableName;
    final recordId = entry.recordId;
    if (table == null || recordId == null || !_softDeleteTables.contains(table)) return;

    final nowUtc = DateTime.now().toUtc();

    if (!kIsWeb) {
      try {
        final isar = IsarService.instance;
        final pending = PendingAuditAction()
          ..actionType = 'restore'
          ..tableName = table
          ..recordId = recordId
          ..tenantId = entry.tenantId
          ..createdAtUtc = nowUtc
          ..syncStatus = SyncStatus.pending;
        await isar.writeTxn(() async => isar.pendingAuditActions.put(pending));
        await processPendingAuditActions();
        return;
      } catch (_) {
        // Isar není k dispozici – fallback na přímý zápis do Supabase
      }
    }

    await _applyRestoreToSupabase(table, recordId);
  }

  /// Trvale odstraní entitu z databáze (DELETE). Offline-first: stejná logika jako u restore.
  static Future<void> hardDelete(AuditLogEntry entry) async {
    final table = entry.tableName;
    final recordId = entry.recordId;
    if (table == null || recordId == null || !_softDeleteTables.contains(table)) return;

    final nowUtc = DateTime.now().toUtc();

    if (!kIsWeb) {
      try {
        final isar = IsarService.instance;
        final pending = PendingAuditAction()
          ..actionType = 'hard_delete'
          ..tableName = table
          ..recordId = recordId
          ..tenantId = entry.tenantId
          ..createdAtUtc = nowUtc
          ..syncStatus = SyncStatus.pending;
        await isar.writeTxn(() async => isar.pendingAuditActions.put(pending));
        await processPendingAuditActions();
        return;
      } catch (_) {
        // Fallback na Supabase
      }
    }

    await _applyHardDeleteToSupabase(table, recordId);
  }

  /// Provede v Supabase UPDATE dané tabulky: deleted_at = null pro daný record_id.
  /// Volá se z restore() a z procesoru fronty PendingAuditAction.
  static Future<void> _applyRestoreToSupabase(String tableName, String recordId) async {
    try {
      await _client.from(tableName).update({'deleted_at': null}).eq('id', recordId);
    } catch (_) {
      rethrow;
    }
  }

  /// Provede v Supabase DELETE řádku v dané tabulce podle id.
  static Future<void> _applyHardDeleteToSupabase(String tableName, String recordId) async {
    try {
      await _client.from(tableName).delete().eq('id', recordId);
    } catch (_) {
      rethrow;
    }
  }

  /// Zpracuje frontu PendingAuditAction v Isar: pending záznamy pošle do Supabase
  /// a označí je jako synced. Volá se po restore/hardDelete na mobilu nebo periodicky.
  static Future<void> processPendingAuditActions() async {
    if (kIsWeb) return;
    try {
      final isar = IsarService.instance;
      final pending = isar.pendingAuditActions
          .filter()
          .syncStatusEqualTo(SyncStatus.pending)
          .findAllSync();
      for (final p in pending) {
        try {
          if (p.actionType == 'restore') {
            await _applyRestoreToSupabase(p.tableName, p.recordId);
          } else if (p.actionType == 'hard_delete') {
            await _applyHardDeleteToSupabase(p.tableName, p.recordId);
          }
          p.syncStatus = SyncStatus.synced;
          await isar.writeTxn(() async => isar.pendingAuditActions.put(p));
        } catch (_) {
          // Jednotlivá akce selhala – necháme záznam pending na další pokus
        }
      }
    } catch (_) {}
  }
}
