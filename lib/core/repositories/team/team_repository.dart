import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro stránkovaný výpis a vyhledávání členů týmu (tabulka profiles).
///
/// PROČ: Při desítkách zaměstnanců nelze stahovat všechny naráz. Pagination +
/// server-side ilike na first_name, last_name, email umožňuje škálovatelný seznam.
/// Vrací surová JSON data – konverzi na [TeamMember] provádí provider.
class TeamRepository {
  TeamRepository._();

  /// Escapuje znaky %, _ a \ pro použití v ilike patternu (PostgreSQL).
  static String _escapeIlikePattern(String s) {
    return s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  }

  /// Stránkovaný výpis členů týmu (profiles) se server-side vyhledáváním.
  ///
  /// [tenantId] – z authNotifierProvider.tenantIdForData.
  /// [limit] – počet řádků na stránku (např. 50).
  /// [offset] – posun (0 = první stránka).
  /// [searchQuery] – volitelný řetězec; pokud neprázdný, filtruje přes
  /// .or('first_name.ilike.%query%,last_name.ilike.%query%,email.ilike.%query%').
  /// Vrací surové záznamy z Supabase – provider je převede na TeamMember.
  static Future<List<Map<String, dynamic>>> getPaginatedTeamMembers(
    String tenantId, {
    required int limit,
    required int offset,
    String? searchQuery,
  }) async {
    if (tenantId.isEmpty) return [];

    final q = searchQuery?.trim() ?? '';
    const selectFull =
        'id, name, first_name, last_name, email, role, roles, status, '
        'weekly_hours, start_date, end_date, zone_preferences, last_sign_in_at';
    const selectMinimal = 'id, name, first_name, last_name, email, role, roles, status';

    // PROČ safeFrom: stejná ochrana jako u mutací – super admin impersonace nesmí
    // omylem načíst profily bez vynuceného tenant filtru na aplikační vrstvě.
    dynamic query = SupabaseService.safeFrom('profiles', tenantId)
        .select(selectFull)
        .isFilter('deleted_at', null)
        .neq('role', 'super_admin');
    if (q.isNotEmpty) {
      final escaped = _escapeIlikePattern(q);
      final pattern = '%$escaped%';
      query = query.or(
        'first_name.ilike.$pattern,last_name.ilike.$pattern,email.ilike.$pattern',
      );
    }
    query = query.order('status').range(offset, offset + limit - 1);

    try {
      final response = await query;
      return List<Map<String, dynamic>>.from(
        (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } on Object catch (_) {
      dynamic queryMin = SupabaseService.safeFrom('profiles', tenantId)
          .select(selectMinimal)
          .isFilter('deleted_at', null)
          .neq('role', 'super_admin');
      if (q.isNotEmpty) {
        final escaped = _escapeIlikePattern(q);
        final pattern = '%$escaped%';
        queryMin = queryMin.or(
          'first_name.ilike.$pattern,last_name.ilike.$pattern,email.ilike.$pattern',
        );
      }
      final response = await queryMin.order('status').range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(
        (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
  }

  /// Minimální sloupce pro mapu `profile_id → display name` u enrich úkolů (P1).
  static Future<List<Map<String, dynamic>>> getTeamIdNameRows(
    String tenantId, {
    required int limit,
  }) async {
    if (tenantId.isEmpty) return [];

    final response = await SupabaseService.safeFrom('profiles', tenantId)
        .select('id, name, first_name, last_name')
        .isFilter('deleted_at', null)
        .neq('role', 'super_admin')
        .order('status')
        .range(0, limit - 1);

    return List<Map<String, dynamic>>.from(
      (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }
}
