import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Jeden záznam z tabulky [support_interventions] – zásah podpory (Magic Login).
///
/// PROČ: Každé přihlášení „jako klient“ musí být auditováno (kdo, u koho, kdy, výkaz práce).
/// Slouží jako podklad pro prevence zneužití Magic Loginu a pro měsíční provize / fakturaci.
class SupportInterventionRow {
  const SupportInterventionRow({
    required this.id,
    required this.profileId,
    required this.tenantId,
    required this.startedAt,
    this.endedAt,
    this.workReport,
    required this.createdAt,
    required this.updatedAt,
    this.profileName,
    this.tenantName,
  });

  final String id;
  final String profileId;
  final String tenantId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? workReport;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Jméno zaměstnance (z join na profiles) – pro zobrazení v seznamu výkazů.
  final String? profileName;
  /// Název agentury (z join na tenants) – pro zobrazení v seznamu výkazů.
  final String? tenantName;

  /// Trvání zásahu v minutách; pokud ještě neskončil, od začátku do teď.
  int durationMinutes(DateTime now) {
    final end = endedAt ?? now;
    return end.difference(startedAt).inMinutes;
  }

  /// Zda zásah ještě probíhá (ended_at je null).
  bool get isActive => endedAt == null;
}

/// Repozitář pro tabulku [support_interventions].
///
/// PROČ: Každé použití Magic Loginu (Přihlásit se jako klient) vytvoří záznam;
/// při návratu do velína se vyžaduje výkaz práce. Záznamy slouží pro audit a provize.
class SupportInterventionsRepository {
  SupportInterventionsRepository();

  /// Vytvoří nový zásah (začátek převtělení). Volá se z AuthNotifier při [impersonateTenant].
  /// Vrací ID nového záznamu pro uložení v AuthNotifier a pozdější [endIntervention].
  Future<String> startIntervention(String profileId, String tenantId) async {
    if (profileId.isEmpty || tenantId.isEmpty) {
      throw ArgumentError('profileId a tenantId musí být neprázdné');
    }
    final res = await SupabaseService.client
        .from('support_interventions')
        .insert({
          'profile_id': profileId,
          'tenant_id': tenantId,
        })
        .select('id')
        .single();
    final id = res['id'] as String?;
    if (id == null || id.isEmpty) throw StateError('INSERT support_interventions nevrátil id');
    return id;
  }

  /// Ukončí zásah: nastaví ended_at a volitelný work_report. Volá se z AuthNotifier při [stopImpersonating].
  Future<void> endIntervention(String interventionId, String? workReport) async {
    if (interventionId.isEmpty) throw ArgumentError('interventionId musí být neprázdný');
    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseService.client.from('support_interventions').update({
      'ended_at': now,
      'work_report': workReport?.trim().isEmpty == true ? null : workReport?.trim(),
      'updated_at': now,
    }).eq('id', interventionId).select();
  }

  /// Najde aktivní zásah (ended_at IS NULL) pro daného zaměstnance.
  /// Slouží k obnově stavu převtělení po obnovení stránky (uložíme tenant_id a id zásahu).
  Future<SupportInterventionRow?> getActiveIntervention(String profileId) async {
    if (profileId.isEmpty) return null;
    final res = await SupabaseService.client
        .from('support_interventions')
        .select('id, profile_id, tenant_id, started_at, ended_at, work_report, created_at, updated_at')
        .eq('profile_id', profileId)
        .isFilter('ended_at', null)
        .maybeSingle();
    if (res == null) return null;
    return _parseRow(Map<String, dynamic>.from(res as Map));
  }

  /// Načte zásahy v daném období (pro zúčtování odměn – součet hodin za měsíc).
  /// [startInclusive] a [endExclusive] v UTC; typicky první den měsíce a první den dalšího měsíce.
  Future<List<SupportInterventionRow>> listInterventionsInPeriod(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final startStr = startInclusive.toUtc().toIso8601String();
    final endStr = endExclusive.toUtc().toIso8601String();
    final res = await SupabaseService.client
        .from('support_interventions')
        .select('id, profile_id, tenant_id, started_at, ended_at, work_report, created_at, updated_at')
        .gte('started_at', startStr)
        .lt('started_at', endStr)
        .order('started_at', ascending: false);
    final list = res as List<dynamic>;
    final result = <SupportInterventionRow>[];
    for (final e in list) {
      try {
        result.add(_parseRow(Map<String, dynamic>.from(e)));
      } catch (e, st) {
        AppLogger.error('SupportInterventionsRepository: parsování řádku (listInterventionsInPeriod) selhalo', e, st);
      }
    }
    return result;
  }

  /// Načte historii zásahů pro Super-Admina (seznam výkazů práce). Řazení od nejnovějších.
  /// Join na profiles a tenants pro zobrazení jmen (Kdo, Agentura).
  Future<List<SupportInterventionRow>> listInterventions({int limit = 500}) async {
    final res = await SupabaseService.client
        .from('support_interventions')
        .select(
          'id, profile_id, tenant_id, started_at, ended_at, work_report, created_at, updated_at, '
          'profiles(name), tenants(name)',
        )
        .order('started_at', ascending: false)
        .limit(limit);
    final list = res as List<dynamic>;
    final result = <SupportInterventionRow>[];
    for (final e in list) {
      try {
        result.add(_parseRowWithJoins(Map<String, dynamic>.from(e)));
      } catch (e, st) {
        AppLogger.error('SupportInterventionsRepository: parsování řádku (listInterventions) selhalo', e, st);
      }
    }
    return result;
  }

  static SupportInterventionRow _parseRow(Map<String, dynamic> m) {
    return SupportInterventionRow(
      id: (m['id'] as String?) ?? '',
      profileId: (m['profile_id'] as String?) ?? '',
      tenantId: (m['tenant_id'] as String?) ?? '',
      startedAt: _parseDateTime(m['started_at']) ?? DateTime.now().toUtc(),
      endedAt: _parseDateTime(m['ended_at']),
      workReport: (m['work_report'] as String?)?.trim(),
      createdAt: _parseDateTime(m['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDateTime(m['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  static SupportInterventionRow _parseRowWithJoins(Map<String, dynamic> m) {
    final row = _parseRow(m);
    String? profileName;
    String? tenantName;
    try {
      final p = m['profiles'];
      if (p is Map) profileName = (p['name'] as String?)?.trim();
    } catch (e, st) {
      AppLogger.error('SupportInterventionsRepository: čtení profiles join v _parseRowWithJoins selhalo', e, st);
    }
    try {
      final t = m['tenants'];
      if (t is Map) tenantName = (t['name'] as String?)?.trim();
    } catch (e, st) {
      AppLogger.error('SupportInterventionsRepository: čtení tenants join v _parseRowWithJoins selhalo', e, st);
    }
    return SupportInterventionRow(
      id: row.id,
      profileId: row.profileId,
      tenantId: row.tenantId,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      workReport: row.workReport,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      profileName: profileName,
      tenantName: tenantName,
    );
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
