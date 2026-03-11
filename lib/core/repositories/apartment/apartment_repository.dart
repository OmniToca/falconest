import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro stránkovaný výpis a vyhledávání apartmánů (tabulka apartments).
///
/// PROČ: Při 100+ bytech nelze stahovat všechny naráz. Pagination + server-side
/// ilike na name/address umožňuje škálovatelný seznam. Vrací surová JSON data –
/// konverzi na [ApartmentRow] provádí provider.
class ApartmentRepository {
  ApartmentRepository._();

  /// Escapuje znaky %, _ a \ pro použití v ilike patternu (PostgreSQL).
  static String _escapeIlikePattern(String s) {
    return s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  }

  /// Stránkovaný výpis apartmánů se server-side vyhledáváním.
  ///
  /// [tenantId] – z authNotifierProvider.tenantIdForData.
  /// [limit] – počet řádků na stránku (např. 50).
  /// [offset] – posun (0 = první stránka).
  /// [searchQuery] – volitelný řetězec; pokud neprázdný, filtruje přes
  /// .or('name.ilike.%query%,address.ilike.%query%').
  /// Vrací surové záznamy z Supabase (List<Map>) – provider je převede na ApartmentRow.
  static Future<List<Map<String, dynamic>>> getPaginatedApartments(
    String tenantId, {
    required int limit,
    required int offset,
    String? searchQuery,
  }) async {
    if (tenantId.isEmpty) return [];

    final q = searchQuery?.trim() ?? '';
    dynamic query = SupabaseService.safeFrom('apartments', tenantId)
        .select(
          'id, name, address, keybox, code, tenant_id, zone_id, status, '
          'check_in_time, check_out_time, standard_cleaning_duration, owner_notes, '
          'monthly_management_fee, managed_from',
        )
        .isFilter('deleted_at', null);

    if (q.isNotEmpty) {
      final escaped = _escapeIlikePattern(q);
      final pattern = '%$escaped%';
      query = query.or(
        'name.ilike.$pattern,address.ilike.$pattern',
      );
    }

    final response = await query.order('name').range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(
      (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }
}
