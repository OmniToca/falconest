import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_address_model.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/repositories/client/client_repository.dart';
import 'package:falconest/core/repositories/settlements/settlement_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/geo_json_point.dart';

/// Příznak „načítám další stránku“ pro konkrétní záložku CRM (nekonečný scroll).
final clientsLoadingMoreByTabProvider =
    StateProvider.family<bool, ClientPaginatedFilterKind>((ref, _) => false);

/// Notifier: stránkovaný seznam klientů pro jednu záložku (owner / agency / external).
///
/// PROČ FamilyAsyncNotifier: Každá záložka má vlastní offset, _hasMore a výsledek dotazu
/// s filtrem client_type na Supabase – žádné dělení jedné odpovědi v paměti.
class PaginatedClientsByTabNotifier
    extends FamilyAsyncNotifier<List<ClientModel>, ClientPaginatedFilterKind> {
  late ClientPaginatedFilterKind _tabKind;
  int _offset = 0;
  static const int _limit = 50;
  bool _hasMore = true;
  String _searchQuery = '';

  Future<List<ClientModel>> _reloadFirstPage() async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return [];

    final list = await ClientRepository.getPaginatedClients(
      tenantId,
      typeTab: _tabKind,
      limit: _limit,
      offset: 0,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );
    _offset = list.length;
    _hasMore = list.length >= _limit;
    return list;
  }

  @override
  Future<List<ClientModel>> build(ClientPaginatedFilterKind tabKind) async {
    _tabKind = tabKind;
    return _reloadFirstPage();
  }

  /// Další stránka stejného typu + stejného vyhledávání (server-side FTS na search_vector).
  Future<void> loadMore() async {
    if (!_hasMore) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    ref.read(clientsLoadingMoreByTabProvider(_tabKind).notifier).state = true;
    try {
      final list = await ClientRepository.getPaginatedClients(
        tenantId,
        typeTab: _tabKind,
        limit: _limit,
        offset: _offset,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
      _offset += list.length;
      _hasMore = list.length >= _limit;

      final state = this.state;
      if (state.hasValue && list.isNotEmpty) {
        this.state = AsyncValue.data([...state.value!, ...list]);
      }
    } finally {
      ref.read(clientsLoadingMoreByTabProvider(_tabKind).notifier).state = false;
    }
  }

  /// Stejný vyhledávací řetězec se aplikuje na všechny záložky z UI (debounce v obrazovce).
  Future<void> search(String query) async {
    _searchQuery = query.trim();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_reloadFirstPage);
  }
}

/// Stránkovaní klienti pro záložku CRM – filtr `client_type` je v Supabase dotazu.
final paginatedClientsByTabProvider = AsyncNotifierProvider.family<
    PaginatedClientsByTabNotifier,
    List<ClientModel>,
    ClientPaginatedFilterKind>(PaginatedClientsByTabNotifier.new);

/// Mapa id → jméno pouze u klientů typu agency (lehký dotaz pro řádky „doporučila agentura …“).
final agencyNamesMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return {};
  return ClientRepository.fetchAgencyIdNameMap(tenantId);
});

/// Počet externích klientů s danou agenturou v poli agency_id (COUNT na serveru).
final recommendedClientsCountByAgencyProvider =
    FutureProvider.autoDispose.family<int, String>((ref, agencyId) async {
  if (agencyId.trim().isEmpty) return 0;
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return 0;
  return ClientRepository.countClientsRecommendedByAgency(tenantId, agencyId);
});

/// Plný seznam doporučených klientů – jen záložka detailu agentury (lazy).
final clientsRecommendedListByAgencyProvider =
    FutureProvider.autoDispose.family<List<ClientModel>, String>((ref, agencyId) async {
  if (agencyId.trim().isEmpty) return [];
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  return ClientRepository.fetchClientsRecommendedByAgency(tenantId, agencyId);
});

/// Invalidace všech tří stránkovaných záložek + sdílených CRM cache po změně dat.
void invalidatePaginatedClientTabs(WidgetRef ref) {
  for (final k in ClientPaginatedFilterKind.values) {
    ref.invalidate(paginatedClientsByTabProvider(k));
  }
}

/// Plný seznam klientů (až 500) pro dropdowny a jiné moduly.
///
/// PROČ: Formuláře (výběr klienta, doporučující agentura) potřebují seznam klientů;
/// stránkované záložky vracejí jen jeden typ. Tento provider načte až 500 záznamů bez filtru typu.
final clientsFullListProvider = FutureProvider<List<ClientModel>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final list = await ClientRepository.getPaginatedClients(
    tenantId,
    typeTab: null,
    limit: 500,
    offset: 0,
    searchQuery: null,
  );
  return list;
});

/// Provider pro přidání nového klienta – vrací async funkci pro insert.
///
/// Při insertu kontrolujeme tenant_id proti authNotifier, aby uživatel
/// nemohl vložit klienta jinému tenantovi (RLS to stejně zablokuje, ale obrana v hloubce).
final addClientProvider = Provider<Future<void> Function(ClientModel client)>((ref) {
  return (ClientModel client) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Žádný tenant v kontextu – nelze přidat klienta.');
    }
    if (client.tenantId != tenantId) {
      throw StateError('Klient musí patřit aktuálnímu tenantovi.');
    }

    final map = client.toMap()
      ..remove('id')
      ..remove('created_at')
      ..remove('deleted_at')
      ..['tenant_id'] = tenantId; // Explicitně přepsat z auth – obrana v hloubce pro RLS

    await SupabaseService.safeFrom('clients', tenantId).insert(map);
  };
});

/// Provider pro úpravu existujícího klienta – soft update (ne mazání).
///
/// Mapuje ClientModel na sloupce tabulky clients. id a tenant_id se nemění.
final updateClientProvider = Provider<Future<void> Function(ClientModel client)>((ref) {
  return (ClientModel client) async {
    if (client.id.isEmpty) {
      throw StateError('Klient bez ID nelze aktualizovat.');
    }
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Žádný tenant v kontextu.');
    }
    if (client.tenantId != tenantId) {
      throw StateError('Klient musí patřit aktuálnímu tenantovi.');
    }

    final map = <String, dynamic>{
      'name': client.name,
      if (client.email != null) 'email': client.email,
      if (client.phone != null) 'phone': client.phone,
      if (client.clientType != null) 'client_type': client.clientType,
      if (client.languageCode != null) 'language_code': client.languageCode,
      'profile_id': client.profileId,
      'agency_id': client.agencyId,
      // PROČ: Explicitně posíláme null, aby dispečer mohl geolokaci v CRM smazat.
      'geo_location': GeoJsonPoint.toPostgrestJson(client.latitude, client.longitude),
    };

    await SupabaseService.safeFrom('clients', tenantId)
        .update(map)
        .eq('id', client.id);
  };
});

/// Provider: stav Klientského portálu pro majitele (profile_id).
///
/// Načte status a last_sign_in_at z profiles. Pokud status == 'pending',
/// sestaví zvací odkaz stejným formátem jako assignClientToApartment
/// ($origin/#/invite?token=$profileId).
///
/// Vrací mapu: status (String), last_login (DateTime?), invite_link (String?).
final clientPortalStatusProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, profileId) async {
  if (profileId.isEmpty) return null;

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return null;

  final res = await SupabaseService.safeFrom('profiles', tenantId)
      .select('status, last_sign_in_at')
      .eq('id', profileId)
      .maybeSingle();

  if (res == null) return null;
  final map = Map<String, dynamic>.from(res);
  final status = (map['status']?.toString() ?? 'pending').toLowerCase();

  DateTime? lastLogin;
  final lastSignIn = map['last_sign_in_at'];
  if (lastSignIn != null) {
    if (lastSignIn is DateTime) {
      lastLogin = lastSignIn;
    } else if (lastSignIn is String) {
      lastLogin = DateTime.tryParse(lastSignIn);
    }
  }

  String? inviteLink;
  if (status == 'pending') {
    final origin = Uri.base.origin;
    inviteLink = origin.trim().isNotEmpty
        ? '$origin/#/invite?token=$profileId'
        : null;
  }

  return {
    'status': status,
    'last_login': lastLogin,
    'invite_link': inviteLink,
  };
});

/// Provider načítající adresy klienta z tabulky [client_addresses].
///
/// Používá se v detailu klienta (typ agency) – Adresář pro transfery.
/// Invaliduj po přidání nebo smazání adresy pro okamžité překreslení seznamu.
final clientAddressesProvider =
    FutureProvider.autoDispose.family<List<ClientAddressModel>, String>((ref, clientId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty || clientId.isEmpty) return [];
  return ClientRepository.fetchAddressesForClient(tenantId, clientId);
});

/// Provider pro soft delete klienta – nastaví deleted_at.
///
/// Důvod: Zachování historie pro úkoly, které na klienta odkazují (client_id).
final softDeleteClientProvider = Provider<Future<void> Function(String clientId)>((ref) {
  return (String clientId) async {
    if (clientId.isEmpty) {
      throw StateError('Nelze smazat klienta bez ID.');
    }
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Žádný tenant v kontextu.');
    }

    await SupabaseService.safeFrom('clients', tenantId)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', clientId);
  };
});

/// Provider: historie provizí (task_commissions) vázaných na klienta – pro záložku Finance.
///
/// PROČ: V detailu klienta zobrazíme vyplacené i čekající částky z modulu Vyúčtování.
/// Řazení od nejnovějších. Závisí na modulu settlements (zámek v UI).
final clientFinancesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  if (clientId.trim().isEmpty) return [];
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  return SettlementRepository.instance.getCommissionsForClient(tenantId, clientId);
});
