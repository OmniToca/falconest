import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';

/// Typ záznamu vráceného z globálního Omnibox vyhledávání.
enum OmniboxEntityType { client, apartment, task }

/// Jednotný záznam Omnibox výsledku napříč CRM (klient), apartmány a úkoly.
///
/// PROČ: Dialog potřebuje jeden společný datový model, aby mohl vykreslit mixed list
/// a po kliknutí předat přesný payload pro otevření detailu bez dalšího mapování v UI vrstvě.
class OmniboxSearchResult {
  const OmniboxSearchResult._({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.client,
    this.apartment,
  });

  final OmniboxEntityType type;
  final String id;
  final String title;
  final String? subtitle;

  /// Používá se při otevření detailu klienta z výsledku.
  final ClientModel? client;

  /// Používá se při otevření detailu apartmánu z výsledku.
  final ApartmentRow? apartment;

  factory OmniboxSearchResult.client(ClientModel client) {
    final type = (client.clientType ?? '').trim();
    final subtitle = [
      if (type.isNotEmpty) type,
      if ((client.email ?? '').trim().isNotEmpty) client.email!.trim(),
      if ((client.phone ?? '').trim().isNotEmpty) client.phone!.trim(),
    ].join(' • ');
    return OmniboxSearchResult._(
      type: OmniboxEntityType.client,
      id: client.id,
      title: client.name.trim().isEmpty ? client.id : client.name.trim(),
      subtitle: subtitle.isEmpty ? null : subtitle,
      client: client,
    );
  }

  factory OmniboxSearchResult.apartment(ApartmentRow apartment) {
    final subtitle = [
      if ((apartment.code ?? '').trim().isNotEmpty) apartment.code!.trim(),
      if ((apartment.address ?? '').trim().isNotEmpty) apartment.address!.trim(),
    ].join(' • ');
    return OmniboxSearchResult._(
      type: OmniboxEntityType.apartment,
      id: apartment.id,
      title: apartment.name.trim().isEmpty ? apartment.id : apartment.name.trim(),
      subtitle: subtitle.isEmpty ? null : subtitle,
      apartment: apartment,
    );
  }

  factory OmniboxSearchResult.task({
    required String id,
    required String title,
    required String? referenceNumber,
    required String? taskType,
    required String? status,
  }) {
    final subtitle = [
      if ((referenceNumber ?? '').trim().isNotEmpty) referenceNumber!.trim(),
      if ((taskType ?? '').trim().isNotEmpty) taskType!.trim(),
      if ((status ?? '').trim().isNotEmpty) status!.trim(),
    ].join(' • ');
    return OmniboxSearchResult._(
      type: OmniboxEntityType.task,
      id: id,
      title: title.trim().isEmpty ? id : title.trim(),
      subtitle: subtitle.isEmpty ? null : subtitle,
    );
  }
}

/// Sdílený textový dotaz Omniboxu.
final omniboxSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Sloučené výsledky Omniboxu napříč klienty, apartmány a úkoly.
///
/// PROČ debounce zde v provideru: dialog může reagovat na každý znak,
/// ale backend dotaz spouštíme až po krátké prodlevě. Tím chráníme DB/Edge API
/// a zároveň držíme konzistentní chování i při případném reuse provideru jinde.
final omniboxSearchResultsProvider =
    FutureProvider.autoDispose<List<OmniboxSearchResult>>((ref) async {
  final rawQuery = ref.watch(omniboxSearchQueryProvider);
  final query = rawQuery.trim();
  if (query.length < 2) return const [];

  await Future<void>.delayed(const Duration(milliseconds: 280));
  if (ref.read(omniboxSearchQueryProvider).trim() != query) {
    return const [];
  }

  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return const [];

  final grouped = await Future.wait<List<OmniboxSearchResult>>([
    _searchClients(tenantId, query),
    _searchApartments(tenantId, query),
    _searchTasks(tenantId, query),
  ]);

  return [
    ...grouped[0],
    ...grouped[1],
    ...grouped[2],
  ];
});

Future<List<OmniboxSearchResult>> _searchClients(
  String tenantId,
  String query,
) async {
  final response = await SupabaseService.safeFrom('clients', tenantId)
      .select(
        'id, tenant_id, name, email, phone, client_type, language_code, profile_id, agency_id, created_at, deleted_at, geo_location',
      )
      .isFilter('deleted_at', null)
      .textSearch(
        'search_vector',
        query,
        config: 'simple',
        type: TextSearchType.websearch,
      )
      .order('name')
      .limit(6);

  return (response as List)
      .map((e) => ClientModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .map(OmniboxSearchResult.client)
      .toList();
}

Future<List<OmniboxSearchResult>> _searchApartments(
  String tenantId,
  String query,
) async {
  final response = await SupabaseService.safeFrom('apartments', tenantId)
      .select(
        'id, name, address, keybox, parking_instructions, review_link, code, tenant_id, zone_id, status, '
        'check_in_time, check_out_time, standard_cleaning_duration, owner_notes, '
        'monthly_management_fee, managed_from, geo_location, deleted_at',
      )
      .isFilter('deleted_at', null)
      .textSearch(
        'search_vector',
        query,
        config: 'simple',
        type: TextSearchType.websearch,
      )
      .order('name')
      .limit(6);

  return (response as List)
      .map((e) => ApartmentRow.fromJson(Map<String, dynamic>.from(e as Map)))
      .map(OmniboxSearchResult.apartment)
      .toList();
}

Future<List<OmniboxSearchResult>> _searchTasks(
  String tenantId,
  String query,
) async {
  final response = await SupabaseService.safeFrom('tasks', tenantId)
      .select('id, title, reference_number, task_type, status, deleted_at, invoiced_at')
      .isFilter('deleted_at', null)
      .isFilter('invoiced_at', null)
      .textSearch(
        'search_vector',
        query,
        config: 'simple',
        type: TextSearchType.websearch,
      )
      .order('scheduled_start', ascending: true)
      .limit(8);

  return (response as List).map((e) {
    final row = Map<String, dynamic>.from(e as Map);
    return OmniboxSearchResult.task(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      referenceNumber: row['reference_number']?.toString(),
      taskType: row['task_type']?.toString(),
      status: row['status']?.toString(),
    );
  }).toList();
}
