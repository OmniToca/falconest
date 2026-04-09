import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:falconest/core/database/drift/app_database.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

/// Repozitář pro `tenant_ui_preferences`: Drift jako primární zápis (offline-first),
/// Supabase jako synchronizovaná pravda po síti.
///
/// PROČ odděleně od [StateNotifier]: Clean Architecture – persistence a síť nepatří do UI vrstvy;
/// provider v dalším kroku pouze zavolá tento repozitář.
class TenantUiPreferencesRepository {
  TenantUiPreferencesRepository({
    required AppDatabase driftDb,
  }) : _db = driftDb;

  final AppDatabase _db;

  static const _uuid = Uuid();

  /// Uloží barvy nejdřív do SQLite, poté se pokusí o upsert na Supabase.
  ///
  /// PROČ pořadí lokálně → server: uživatel musí okamžitě vidět změnu i bez sítě; při výpadku
  /// zůstane pravda v Driftu a [syncFromServer] nebo další pokus dorovná server později.
  ///
  /// PROČ try-catch kolem Supabase: offline nebo timeout nesmí shodit celou aplikaci – pouze
  /// zalogujeme (bez snackbarů), aby UX zůstalo stabilní a data zůstala v SQLite.
  Future<void> savePreferences({
    required String tenantId,
    String? primaryColor,
    String? secondaryColor,
  }) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) {
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    final existing = await _selectByTenantId(tid);
    final rowId = existing?.id ?? _uuid.v4();

    if (existing != null) {
      await (_db.update(_db.tenantUiPreferences)
            ..where((t) => t.id.equals(existing.id)))
          .write(
        TenantUiPreferencesCompanion(
          primaryColor: Value(primaryColor),
          secondaryColor: Value(secondaryColor),
          updatedAt: Value(nowUtc),
        ),
      );
    } else {
      await _db.into(_db.tenantUiPreferences).insert(
            TenantUiPreferencesCompanion.insert(
              id: rowId,
              tenantId: tid,
              primaryColor: Value(primaryColor),
              secondaryColor: Value(secondaryColor),
              updatedAt: nowUtc,
            ),
          );
    }

    try {
      await SupabaseService.safeFrom('tenant_ui_preferences', tid).upsert(
            SupabaseService.safeInsertPayload(tid, {
              'id': rowId,
              'primary_color': primaryColor,
              'secondary_color': secondaryColor,
              'updated_at': nowUtc.toIso8601String(),
            }),
            onConflict: 'tenant_id',
          );
    } catch (e, st) {
      developer.log(
        'TenantUiPreferencesRepository: upsert na Supabase selhal (offline nebo RLS/síť). '
        'Lokální Drift už obsahuje nejnovější stav; synchronizace proběhne při dalším online pokusu.',
        name: 'TenantUiPreferencesRepository',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Stáhne řádek ze Supabase a přepíše Drift, pouze pokud je serverový [updated_at] novější.
  ///
  /// PROČ Timestamp Merging: dva klienti (web + mobil) nesmí slepě přepsat novější změnu;
  /// porovnáváme UTC časové značky. Pokud je lokální stejně nový nebo novější, server neaplikujeme.
  ///
  /// PROČ mazání podle [tenantId] před insertem: po prvním offline zápisu může mít Drift jiné UUID
  /// [id] než později vrátí server – unikátní constraint na [tenantId] vyžaduje jeden řádek na tenant.
  Future<void> syncFromServer(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) {
      return;
    }

    try {
      final res = await SupabaseService.safeFrom('tenant_ui_preferences', tid)
          .select(
            'id, tenant_id, primary_color, secondary_color, updated_at',
          )
          .maybeSingle();

      if (res == null) {
        return;
      }

      final map = Map<String, dynamic>.from(res as Map);
      final serverUpdated = _parseDateTimeUtc(map['updated_at']);
      if (serverUpdated == null) {
        return;
      }

      final local = await _selectByTenantId(tid);
      if (local != null && !serverUpdated.isAfter(local.updatedAt)) {
        return;
      }

      final serverId = map['id']?.toString().trim() ?? '';
      if (serverId.isEmpty) {
        return;
      }

      await _db.transaction(() async {
        await (_db.delete(_db.tenantUiPreferences)
              ..where((t) => t.tenantId.equals(tid)))
            .go();

        await _db.into(_db.tenantUiPreferences).insert(
              TenantUiPreferencesCompanion.insert(
                id: serverId,
                tenantId: tid,
                primaryColor: Value(map['primary_color']?.toString()),
                secondaryColor: Value(map['secondary_color']?.toString()),
                updatedAt: serverUpdated,
              ),
            );
      });
    } catch (e, st) {
      developer.log(
        'TenantUiPreferencesRepository: syncFromServer selhal (síť, RLS, nebo tabulka ještě neexistuje v projektu).',
        name: 'TenantUiPreferencesRepository',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Aktuální lokální řádek pro tenant (pro budoucí provider / testy).
  Future<TenantUiPreference?> getLocal(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) {
      return null;
    }
    return _selectByTenantId(tid);
  }

  Future<TenantUiPreference?> _selectByTenantId(String tenantId) {
    return (_db.select(_db.tenantUiPreferences)
          ..where((t) => t.tenantId.equals(tenantId)))
        .getSingleOrNull();
  }

  /// Parsování hodnoty `updated_at` z PostgREST (String nebo DateTime).
  static DateTime? _parseDateTimeUtc(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw.toUtc();
    }
    return DateTime.tryParse(raw.toString())?.toUtc();
  }
}
