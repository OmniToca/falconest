import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_address_model.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/repositories/client/client_repository.dart';
import 'package:falconest/core/repositories/settlements/settlement_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Příznak, zda se načítá další stránka (nekonečný scroll).
/// Notifier ho nastavuje v loadMore() pro zobrazení indikátoru na konci seznamu.
final clientsLoadingMoreProvider = StateProvider<bool>((ref) => false);

/// Notifier pro stránkovaný seznam klientů se server-side vyhledáváním.
///
/// PROČ: Při 1000+ klientech nelze stahovat všechny naráz. build() načte první stránku,
/// loadMore() připojuje další, search(query) resetuje a načte s filtrem.
class PaginatedClientsNotifier extends AsyncNotifier<List<ClientModel>> {
  int _offset = 0;
  static const int _limit = 50;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  Future<List<ClientModel>> build() async {
    _offset = 0;
    _hasMore = true;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return [];

    final list = await ClientRepository.getPaginatedClients(
      tenantId,
      limit: _limit,
      offset: 0,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );
    _offset = list.length;
    _hasMore = list.length >= _limit;
    return list;
  }

  /// Načte další stránku a připojí ji k aktuálnímu seznamu.
  /// Volá se při scrollu ke konci seznamu. Pokud _hasMore je false, nic nedělá.
  Future<void> loadMore() async {
    if (!_hasMore) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    ref.read(clientsLoadingMoreProvider.notifier).state = true;
    try {
      final list = await ClientRepository.getPaginatedClients(
        tenantId,
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
      ref.read(clientsLoadingMoreProvider.notifier).state = false;
    }
  }

  /// Server-side vyhledávání: reset offsetu, nastaví dotaz a načte první stránku.
  /// Volá se z UI s debounce (např. 500 ms po posledním stisku).
  Future<void> search(String query) async {
    _searchQuery = query.trim();
    _offset = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Provider stránkovaného seznamu klientů pro obrazovku Klienti.
///
/// Používá PaginatedClientsNotifier – build() načte první stránku, loadMore() a search()
/// volá UI. ref.watch(clientsProvider) vrací AsyncValue<List<ClientModel>>.
/// Ostatní obrazovky (dropdowny, detail) používají [clientsFullListProvider].
final clientsProvider =
    AsyncNotifierProvider<PaginatedClientsNotifier, List<ClientModel>>(
  PaginatedClientsNotifier.new,
);

/// Plný seznam klientů (až 500) pro dropdowny a jiné moduly.
///
/// PROČ: Formuláře (výběr klienta, doporučující agentura) potřebují seznam klientů;
/// stránkovaný provider vrací jen načtené stránky. Tento provider načte jedním dotazem
/// až 500 záznamů bez vyhledávání – pro výběr z dropdownu stačí.
final clientsFullListProvider = FutureProvider<List<ClientModel>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final list = await ClientRepository.getPaginatedClients(
    tenantId,
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
      'profile_id': client.profileId,
      'agency_id': client.agencyId,
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

  final res = await SupabaseService.client
      .from('profiles')
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

/// Provider: seznam externích klientů doporučených danou agenturou.
///
/// PROČ: Tab "Doporučení klienti" u detailu agentury – zobrazí klienty s agency_id =
/// ID této agentury. Slouží pro přehled, kdo nám klienta přivedl.
final clientsRecommendedByAgencyProvider =
    FutureProvider.autoDispose.family<List<ClientModel>, String>((ref, agencyId) async {
  if (agencyId.trim().isEmpty) return [];
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final response = await SupabaseService.safeFrom('clients', tenantId)
      .select('id, tenant_id, name, email, phone, client_type, profile_id, agency_id, created_at, deleted_at')
      .eq('agency_id', agencyId)
      .isFilter('deleted_at', null)
      .order('name');

  return (response as List)
      .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
      .toList();
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
