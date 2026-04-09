import 'package:falconest/core/models/client_address_model.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/services/supabase_service.dart';
// TextSearchType je re-export z postgrest přes supabase_flutter.
import 'package:supabase_flutter/supabase_flutter.dart';

/// Filtr typu klienta pro stránkovaný výpis na záložkách CRM (Majitelé / Agentury / Externí).
///
/// PROČ samostatný enum: Supabase dotaz musí filtrovat přímo na backendu, ne až dělením
/// v paměti – jinak jsou záložky poloprázdné. Hodnota [external] zahrnuje `external` i NULL.
enum ClientPaginatedFilterKind {
  owner,
  agency,
  external,
}

/// Repozitář pro CRUD operace nad klienty a jejich adresami (client_addresses).
///
/// Adresář klienta (Varianta A): U partnerských agenturách (client_type = 'agency')
/// ukládáme jejich externí adresy – např. "Apartmán u moře", "Kancelář v centru".
/// Umožňuje řidičům znát přesné lokace pro vyzvednutí/odvoz při transferech.
///
/// VŠECHNY dotazy jsou vázány na tenant_id – multi-tenant izolace.
/// Soft delete: u deleteClientAddress se používá UPDATE deleted_at místo fyzického DELETE.
class ClientRepository {
  ClientRepository._();

  /// Stránkovaný výpis klientů se server-side vyhledáváním.
  ///
  /// PROČ: Při 1000+ klientech nelze stahovat všechny naráz. Full-Text Search nad sloupcem
  /// [clients.search_vector] (GIN, konfigurace `simple`) místo tří `ilike` — měřítko a relevance.
  /// [TextSearchType.websearch] mapuje na `websearch_to_tsquery` (bezpečné pro surový vstup z UI).
  ///
  /// [tenantId] – z authNotifierProvider.tenantIdForData.
  /// [limit] – počet řádků na stránku (např. 50).
  /// [offset] – posun (0 = první stránka).
  /// [searchQuery] – volitelný řetězec; pokud neprázdný, filtr přes `.textSearch('search_vector', ...)`.
  ///
  /// [typeTab]: pokud null, žádný filtr podle client_type (dropdowny, plný export až 500 řádků).
  /// Pokud vyplněno, stránkuje jen danou záložku CRM přímo v SQL/PostgREST.
  static Future<List<ClientModel>> getPaginatedClients(
    String tenantId, {
    ClientPaginatedFilterKind? typeTab,
    required int limit,
    required int offset,
    String? searchQuery,
  }) async {
    if (tenantId.isEmpty) return [];

    final q = searchQuery?.trim() ?? '';
    dynamic query = SupabaseService.safeFrom('clients', tenantId)
        .select(
          'id, tenant_id, name, email, phone, client_type, language_code, profile_id, agency_id, created_at, deleted_at, geo_location',
        )
        .isFilter('deleted_at', null);

    query = _applyClientTypeTabFilter(query, typeTab);

    if (q.isNotEmpty) {
      query = query.textSearch(
        'search_vector',
        q,
        config: 'simple',
        type: TextSearchType.websearch,
      );
    }

    final response = await query.order('name').range(offset, offset + limit - 1);
    return (response as List)
        .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Aplikuje filtr záložky (owner / agency / external+NULL) na builder dotazu clients.
  static dynamic _applyClientTypeTabFilter(
    dynamic query,
    ClientPaginatedFilterKind? typeTab,
  ) {
    if (typeTab == null) return query;
    switch (typeTab) {
      case ClientPaginatedFilterKind.owner:
        return query.eq('client_type', 'owner');
      case ClientPaginatedFilterKind.agency:
        return query.eq('client_type', 'agency');
      case ClientPaginatedFilterKind.external:
        // PostgREST: externí typ nebo chybějící client_type (staré záznamy).
        return query.or('client_type.eq.external,client_type.is.null');
    }
  }

  /// Lehká mapa id → jméno jen pro agentury (záložka Externí – řádek „doporučila agentura X“).
  ///
  /// PROČ: Nepotřebujeme stahovat 500 celých klientů jen kvůli jednomu jménu.
  static Future<Map<String, String>> fetchAgencyIdNameMap(String tenantId) async {
    if (tenantId.isEmpty) return {};

    final res = await SupabaseService.safeFrom('clients', tenantId)
        .select('id, name')
        .eq('client_type', 'agency')
        .isFilter('deleted_at', null)
        .order('name');

    final map = <String, String>{};
    for (final row in res as List) {
      final m = row as Map<String, dynamic>;
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      map[id] = (m['name'] as String?)?.trim() ?? '';
    }
    return map;
  }

  /// Počet externích klientů doporučených danou agenturou (jen COUNT na serveru).
  static Future<int> countClientsRecommendedByAgency(
    String tenantId,
    String agencyId,
  ) async {
    if (tenantId.isEmpty || agencyId.trim().isEmpty) return 0;

    final res = await SupabaseService.safeFrom('clients', tenantId)
        .select('id')
        .eq('agency_id', agencyId.trim())
        .isFilter('deleted_at', null)
        .count(CountOption.exact);

    return res.count;
  }

  /// Plný seznam doporučených klientů pro záložku v detailu agentury (lazy – až po otevření tabu).
  static Future<List<ClientModel>> fetchClientsRecommendedByAgency(
    String tenantId,
    String agencyId,
  ) async {
    if (tenantId.isEmpty || agencyId.trim().isEmpty) return [];

    final response = await SupabaseService.safeFrom('clients', tenantId)
        .select(
          'id, tenant_id, name, email, phone, client_type, language_code, profile_id, agency_id, created_at, deleted_at, geo_location',
        )
        .eq('agency_id', agencyId.trim())
        .isFilter('deleted_at', null)
        .order('name');

    return (response as List)
        .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Načte všechny aktivní adresy daného klienta (deleted_at IS NULL).
  ///
  /// PROČ: Při vytváření transferu k externí agentuře zobrazíme výběr jejích adres –
  /// dispečer vybere "Apartmán u moře" místo ručního vepisování. Řazeno podle labelu.
  ///
  /// [tenantId] – z authNotifierProvider.tenantIdForData (RLS to stejně ověří).
  /// [clientId] – UUID klienta z tabulky clients.
  static Future<List<ClientAddressModel>> fetchAddressesForClient(
    String tenantId,
    String clientId,
  ) async {
    if (tenantId.isEmpty || clientId.isEmpty) return [];

    final res = await SupabaseService.safeFrom('client_addresses', tenantId)
        .select('id, tenant_id, client_id, label, address, created_at, updated_at, deleted_at')
        .eq('client_id', clientId)
        .isFilter('deleted_at', null)
        .order('label');

    return (res as List)
        .map((e) => ClientAddressModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Přidá novou adresu ke klientovi.
  ///
  /// PROČ: Dispečer přidává adresu partnerské agentury – např. nové pobytové místo.
  /// RLS ověří, že client_id patří klientovi z téhož tenanta.
  ///
  /// [tenantId] – z authNotifierProvider.tenantIdForData.
  /// [clientId] – UUID klienta (clients.id).
  /// [label] – lidsky čitelný název (např. "Apartmán u moře").
  /// [address] – plná adresa pro řidiče.
  static Future<ClientAddressModel> addAddressToClient(
    String tenantId,
    String clientId, {
    required String label,
    required String address,
  }) async {
    if (tenantId.isEmpty) {
      throw StateError('Tenant ID je povinný pro přidání adresy.');
    }
    if (clientId.isEmpty) {
      throw StateError('Client ID je povinný pro přidání adresy.');
    }
    final labelTrimmed = label.trim();
    final addressTrimmed = address.trim();
    if (labelTrimmed.isEmpty) {
      throw StateError('Label (název) adresy nesmí být prázdný.');
    }
    if (addressTrimmed.isEmpty) {
      throw StateError('Adresa nesmí být prázdná.');
    }

    final map = <String, dynamic>{
      'tenant_id': tenantId,
      'client_id': clientId,
      'label': labelTrimmed,
      'address': addressTrimmed,
    };

    final res = await SupabaseService.safeFrom('client_addresses', tenantId)
        .insert(map)
        .select()
        .single();

    return ClientAddressModel.fromJson(Map<String, dynamic>.from(res));
  }

  /// Soft delete adresy – nastaví deleted_at.
  ///
  /// PROČ: Zachování historie – úkoly mohou odkazovat na adresu v metadata.
  /// Fyzické mazání by zlomilo audit. Soft delete je konzistentní s clients a ostatními tabulkami.
  ///
  /// [tenantId] – z authNotifierProvider.tenantIdForData (obrana v hloubce).
  /// [addressId] – UUID záznamu v client_addresses.
  static Future<void> deleteClientAddress(
    String tenantId,
    String addressId,
  ) async {
    if (tenantId.isEmpty) {
      throw StateError('Tenant ID je povinný pro smazání adresy.');
    }
    if (addressId.isEmpty) {
      throw StateError('Nelze smazat adresu bez ID.');
    }

    await SupabaseService.safeFrom('client_addresses', tenantId)
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', addressId);
  }
}
