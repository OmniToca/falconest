import 'package:isar/isar.dart';

import 'sync_status.dart';

part 'pending_audit_action.g.dart';

/// Lokální Isar záznam o akci „Obnovit“ nebo „Trvalé odstranění“ z audit logu.
///
/// Offline-first: Super Admin může v modulu Odpadkový koš zvolit obnovu nebo
/// hard delete. Zápis jde nejdřív sem (s UTC časem pro Timestamp Merging),
/// na pozadí se synchronizuje do Supabase (UPDATE deleted_at = null resp. DELETE).
/// Na webu Isar neběží – tam se volá Supabase přímo z provideru.
///
@collection
class PendingAuditAction {
  Id id = Isar.autoIncrement;

  /// Typ akce: restore = nastavení deleted_at = null na původní entitě,
  /// hard_delete = fyzické smazání řádku z tabulky.
  late String actionType;

  /// Tabulka původní entity (apartments, tasks, profiles, reservations).
  late String tableName;

  /// UUID záznamu v Supabase (record_id z audit_logs).
  late String recordId;

  /// Tenant ID pro multi-tenant kontext (nullable u globálních záznamů).
  String? tenantId;

  /// Čas vytvoření záznamu v UTC. Používá se pro řazení a Timestamp Merging
  /// při synchronizaci – konzistentní časová razítka zajišťují správné pořadí.
  late DateTime createdAtUtc;

  /// Stav synchronizace: pending = čeká na odeslání do Supabase,
  /// synced = akce již byla provedena v cloudu.
  @enumerated
  late SyncStatus syncStatus;
}
