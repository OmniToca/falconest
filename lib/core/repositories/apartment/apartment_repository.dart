import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro stránkovaný výpis a vyhledávání apartmánů (tabulka apartments).
///
/// PROČ: Při 100+ bytech nelze stahovat všechny naráz. Pagination + server-side
/// ilike na name/address umožňuje škálovatelný seznam. Vrací surová JSON data –
/// konverzi na [ApartmentRow] provádí provider. Zápis (insert/update) centralizujeme
/// sem, aby admin UI nemuselo duplikovat volání Supabase a vždy posílalo stejná pole.
class ApartmentRepository {
  ApartmentRepository._();

  /// Sloupce pro výpis apartmánů – musí obsahovat vše, co parsuje [ApartmentRow.fromJson].
  static const String _listSelectColumns =
      'id, name, address, keybox, parking_instructions, review_link, code, tenant_id, zone_id, status, '
      'check_in_time, check_out_time, standard_cleaning_duration, owner_notes, '
      'monthly_management_fee, managed_from, geo_location, investment_tracking_enabled, '
      'rental_mode, lease_start_date, lease_end_date, '
      'rent_amount, rent_due_day, rent_collection_mode, rent_task_assignee_id';

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
        .select(_listSelectColumns)
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

  /// Aktualizace řádku bytu (admin dialog úpravy).
  ///
  /// PROČ: Jedno místo pro PATCH – snadné doplnění nových sloupců bez hledání
  /// `safeFrom('apartments')` po celém projektu.
  static Future<void> updateApartment(
    String tenantId,
    String apartmentId,
    Map<String, dynamic> patch,
  ) async {
    if (tenantId.isEmpty || apartmentId.isEmpty) return;
    await SupabaseService.safeFrom('apartments', tenantId)
        .update(patch)
        .eq('id', apartmentId);
  }

  /// Vložení nového bytu; vrací serverové UUID.
  ///
  /// [row] musí obsahovat všechny povinné sloupce včetně `tenant_id` (stejně jako dříve insert v UI).
  static Future<String> insertApartment(
    String tenantId,
    Map<String, dynamic> row,
  ) async {
    if (tenantId.isEmpty) {
      throw ArgumentError.value(tenantId, 'tenantId', 'must be non-empty');
    }
    final res = await SupabaseService.safeFrom('apartments', tenantId)
        .insert(row)
        .select('id')
        .single();
    final newId = res['id'] as String?;
    if (newId == null || newId.isEmpty) {
      throw StateError('admin.apartments_error_insert_no_id');
    }
    return newId;
  }
}
