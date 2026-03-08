import 'package:falconest/core/models/client_address_model.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/services/supabase_service.dart';

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

  /// Escapuje znaky %, _ a \ pro použití v ilike patternu (PostgreSQL).
  static String _escapeIlikePattern(String s) {
    return s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  }

  /// Stránkovaný výpis klientů se server-side vyhledáváním.
  ///
  /// PROČ: Při 1000+ klientech nelze stahovat všechny naráz. Pagination + ilike
  /// na name/email/phone umožňuje škálovatelný seznam a vyhledávání na backendu.
  ///
  /// [tenantId] – z authNotifierProvider.tenantIdForData.
  /// [limit] – počet řádků na stránku (např. 50).
  /// [offset] – posun (0 = první stránka).
  /// [searchQuery] – volitelný řetězec; pokud neprázdný, filtruje přes .or('name.ilike.%query%,...').
  static Future<List<ClientModel>> getPaginatedClients(
    String tenantId, {
    required int limit,
    required int offset,
    String? searchQuery,
  }) async {
    if (tenantId.isEmpty) return [];

    final q = searchQuery?.trim() ?? '';
    dynamic query = SupabaseService.client
        .from('clients')
        .select(
          'id, tenant_id, name, email, phone, client_type, profile_id, agency_id, created_at, deleted_at',
        )
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);

    if (q.isNotEmpty) {
      final escaped = _escapeIlikePattern(q);
      final pattern = '%$escaped%';
      query = query.or(
        'name.ilike.$pattern,email.ilike.$pattern,phone.ilike.$pattern',
      );
    }

    final response = await query.order('name').range(offset, offset + limit - 1);
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

    final res = await SupabaseService.client
        .from('client_addresses')
        .select('id, tenant_id, client_id, label, address, created_at, updated_at, deleted_at')
        .eq('tenant_id', tenantId)
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

    final res = await SupabaseService.client
        .from('client_addresses')
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

    await SupabaseService.client
        .from('client_addresses')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', addressId)
        .eq('tenant_id', tenantId);
  }
}
