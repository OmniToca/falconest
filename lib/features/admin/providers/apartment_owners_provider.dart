import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';

/// Model majitele přiřazeného k apartmánu – pro zobrazení v UI.
///
/// Spojuje záznam z apartment_owners s údaji z profiles (nebo invitations).
/// [isPending] true = majitel ještě neakceptoval pozvánku (ghost profil bez auth_id).
/// [isPrimaryBilling] true = u spoluvlastnictví tento majitel je hlavní plátce (fakturace jde jen jemu).
class ApartmentOwnerRow {
  const ApartmentOwnerRow({
    required this.id,
    required this.ownerId,
    required this.name,
    this.email,
    required this.isPending,
    this.isPrimaryBilling = false,
  });

  /// apartment_owners.id (UUID záznamu propojení)
  final String id;
  /// profiles.id – odkaz na profil majitele
  final String ownerId;
  final String name;
  final String? email;
  /// true = čeká na registraci (invitation), false = aktivní profil
  final bool isPending;
  /// U spoluvlastnictví: true = hlavní plátce za fakturaci (paušál a úkoly)
  final bool isPrimaryBilling;
}

/// Provider načítající majitele přiřazené k danému apartmánu.
///
/// Dotaz na apartment_owners s JOIN na profiles. Soft delete: pouze
/// záznamy s deleted_at IS NULL. Sloupec tenant_id (denormalizace z apartments) umožňuje
/// striktní [SupabaseService.safeFrom] na klientovi – dříve spoléhání jen na RLS + apartment_id.
/// BUGFIX: Explicitní hint !apartment_owners_owner_id_fkey pro PostgREST –
/// zajistí správný JOIN při více FK vazbách a po doplnění migrace 20260223.
final apartmentOwnersForApartmentProvider =
    FutureProvider.autoDispose.family<List<ApartmentOwnerRow>, String>((ref, apartmentId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final res = await SupabaseService.safeFrom('apartment_owners', tenantId)
      .select(
        'id, owner_id, is_primary_billing, profiles!apartment_owners_owner_id_fkey(id, name, first_name, last_name, email, status)',
      )
      .eq('apartment_id', apartmentId)
      .isFilter('deleted_at', null);

  return _parseOwnerRows(res as List);
});

/// Parsuje odpověď Supabase na seznam [ApartmentOwnerRow].
List<ApartmentOwnerRow> _parseOwnerRows(List<dynamic> raw) {
  final result = <ApartmentOwnerRow>[];
  for (final item in raw) {
    final map = item as Map<String, dynamic>;
    final id = map['id']?.toString() ?? '';
    final ownerId = map['owner_id']?.toString() ?? '';
    if (id.isEmpty || ownerId.isEmpty) continue;
    final isPrimaryBilling = map['is_primary_billing'] == true;

    final profilesData = map['profiles'];
    String name = '–';
    String? email;
    bool isPending = true;
    if (profilesData != null && profilesData is Map) {
      final p = profilesData as Map<String, dynamic>;
      final n = p['name']?.toString().trim();
      final fn = p['first_name']?.toString().trim();
      final ln = p['last_name']?.toString().trim();
      if (n != null && n.isNotEmpty) {
        name = n;
      } else if (fn != null || ln != null) {
        name = '$fn $ln'.trim();
      }
      email = p['email']?.toString().trim();
      if (email != null && email.isEmpty) email = null;
      isPending = (p['status']?.toString() ?? '').toLowerCase() == 'pending';
    }
    result.add(ApartmentOwnerRow(
      id: id,
      ownerId: ownerId,
      name: name,
      email: email,
      isPending: isPending,
      isPrimaryBilling: isPrimaryBilling,
    ));
  }
  return result;
}

/// Provider: agregovaný počet apartmánů na majitele (owner_id → count).
///
/// Jeden dotaz na apartment_owners pro celý tenant. Slouží pro zobrazení
/// "Počet apartmánů: X" na kartě majitele v modulu Klienti bez rizika N+1.
/// PROČ safeFrom: tenant_id je přímo na apartment_owners – join na apartments už není nutný pro izolaci.
final ownerApartmentCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return {};

  final res = await SupabaseService.safeFrom('apartment_owners', tenantId)
      .select('owner_id')
      .isFilter('deleted_at', null);

  final map = <String, int>{};
  for (final item in (res as List)) {
    final ownerId = (item as Map<String, dynamic>)['owner_id']?.toString().trim();
    if (ownerId == null || ownerId.isEmpty) continue;
    map[ownerId] = (map[ownerId] ?? 0) + 1;
  }
  return map;
});

/// Provider: apartmány přiřazené majiteli (profileId = owner_id v apartment_owners).
///
/// Lazy-loaded dotaz – načte se až při otevření tabu Apartmány v detailu klienta.
/// SELECT apartments s inner join apartment_owners WHERE owner_id = profileId.
/// Filtrujeme jen aktivní propojení (apartment_owners.deleted_at IS NULL), aby se
/// po odebrání majitele apartmán v záložce Apartmány nezobrazoval.
final apartmentsForProfileProvider =
    FutureProvider.autoDispose.family<List<ApartmentRow>, String>((ref, profileId) async {
  if (profileId.trim().isEmpty) return [];
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final res = await SupabaseService.safeFrom('apartments', tenantId)
      .select(
        'id, name, address, keybox, parking_instructions, review_link, tenant_id, zone_id, status, '
        'check_in_time, check_out_time, standard_cleaning_duration, owner_notes, '
        'geo_location, '
        'apartment_owners!inner(owner_id)',
      )
      .eq('apartment_owners.owner_id', profileId)
      .isFilter('apartment_owners.deleted_at', null)
      .isFilter('deleted_at', null)
      .order('name');

  return (res as List)
      .map((e) => ApartmentRow.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Provider: seznam všech profilů s rolí property_owner v aktuálním tenantovi.
///
/// Používá se pro výběr "Přidat existujícího majitele". Vrací pouze aktivní
/// profily (profiles) + pozvánky s role=property_owner. Exkluze již přiřazených
/// k danému bytu se řeší v UI (dropdown filtruje).
final propertyOwnersInTenantProvider = FutureProvider<List<PropertyOwnerOption>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final profilesRes = await SupabaseService.safeFrom('profiles', tenantId)
      .select('id, name, first_name, last_name, email, status')
      .eq('role', 'property_owner')
      .isFilter('deleted_at', null);

  final invitationsRes = await SupabaseService.safeFrom('invitations', tenantId)
      .select('id, profile_id, email, first_name, last_name')
      .eq('role', 'property_owner');

  final result = <PropertyOwnerOption>[];
  for (final p in (profilesRes as List)) {
    final map = p as Map<String, dynamic>;
    final id = map['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final name = _displayName(map);
    final email = map['email']?.toString().trim();
    final isPending = (map['status']?.toString() ?? '').toLowerCase() == 'pending';
    result.add(PropertyOwnerOption(
      profileId: id,
      name: name,
      email: email,
      isPending: isPending,
    ));
  }
  for (final inv in (invitationsRes as List)) {
    final map = inv as Map<String, dynamic>;
    final profileId = map['profile_id']?.toString() ?? '';
    if (profileId.isEmpty) continue;
    // Vynech pokud už je v profiles (duplicita)
    if (result.any((o) => o.profileId == profileId)) continue;
    final fn = map['first_name']?.toString().trim() ?? '';
    final ln = map['last_name']?.toString().trim() ?? '';
    final email = map['email']?.toString().trim();
    final name = '$fn $ln'.trim();
    result.add(PropertyOwnerOption(
      profileId: profileId,
      name: name.isNotEmpty ? name : (email ?? '–'),
      email: email,
      isPending: true,
    ));
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
});

String _displayName(Map<String, dynamic> p) {
  final n = p['name']?.toString().trim();
  if (n != null && n.isNotEmpty) return n;
  final fn = p['first_name']?.toString().trim() ?? '';
  final ln = p['last_name']?.toString().trim() ?? '';
  final combined = '$fn $ln'.trim();
  if (combined.isNotEmpty) return combined;
  final email = p['email']?.toString().trim();
  return email ?? '–';
}

/// Volba pro dropdown "Přidat existujícího majitele".
class PropertyOwnerOption {
  const PropertyOwnerOption({
    required this.profileId,
    required this.name,
    this.email,
    required this.isPending,
  });

  final String profileId;
  final String name;
  final String? email;
  final bool isPending;
}

/// Repozitář pro CRUD operace nad apartment_owners.
class ApartmentOwnersRepository {
  ApartmentOwnersRepository._();

  /// Zajistí propojení majitel–byt: pokud existuje soft-deleted záznam, obnoví ho,
  /// jinak vloží nový řádek. Tím se vyhneme chybě duplicate key při znovupřidání majitele.
  /// PROČ safeFrom + safeInsertPayload: každý řádek nese tenant_id synchronně s bytem (migrace + insert).
  static Future<void> _ensureOwnerLinked({
    required String apartmentId,
    required String ownerId,
    required String tenantId,
  }) async {
    final existing = await SupabaseService.safeFrom('apartment_owners', tenantId)
        .select('id, deleted_at')
        .eq('apartment_id', apartmentId)
        .eq('owner_id', ownerId)
        .maybeSingle();

    if (existing != null) {
      final id = (existing as Map)['id']?.toString();
      final deletedAt = (existing as Map)['deleted_at'];
      if (id != null && id.isNotEmpty && deletedAt != null) {
        await SupabaseService.safeFrom('apartment_owners', tenantId)
            .update({'deleted_at': null})
            .eq('id', id);
      }
      return;
    }

    await SupabaseService.safeFrom('apartment_owners', tenantId).insert({
      'apartment_id': apartmentId,
      'owner_id': ownerId,
    });
  }

  /// Přiřadí CRM klienta (majitele) k apartmánu. Pokud klient nemá profile_id,
  /// automaticky vytvoří ghost profil, pozvánku a uloží profile_id do clients.
  ///
  /// FLOW:
  /// a) client.profileId != null → použij jako targetProfileId, pozvánkový odkaz nevracíme
  ///    (majitel už má přístup nebo byl dříve pozván).
  /// b) client.profileId == null → vytvoř ghost profil (profiles) s role=property_owner,
  ///    vytvoř záznam v invitations, ulož profile_id do clients, vrať pozvánkový odkaz
  ///    pro WhatsApp/sdílení. Token v URL musí být **`invitations.id`** (ne profile_id), aby
  ///    `InviteRepository.fetchInvitationByToken` našel řádek podle primárního klíče.
  /// c) INSERT do apartment_owners (apartment_id, owner_id=targetProfileId).
  ///
  /// [baseOrigin] – základ URL aplikace pro pozvánkový odkaz (např. Uri.base.origin na webu).
  /// Pokud null, použije se Uri.base.origin.
  static Future<String?> assignClientToApartment({
  required String apartmentId,
  required String tenantId,
  required ClientModel client,
  String? baseOrigin,
}) async {
  String targetProfileId;
  String? inviteLink;
  final origin = baseOrigin ?? Uri.base.origin;

  if (client.profileId != null && client.profileId!.trim().isNotEmpty) {
    targetProfileId = client.profileId!.trim();
  } else {
    final email = client.email?.trim() ?? '';
    if (email.isEmpty) {
      throw ArgumentError(
        'Klient musí mít vyplněný e-mail pro vytvoření pozvánky do Klientského portálu.',
      );
    }
    var displayName = client.name.trim();
    if (displayName.isEmpty) displayName = email.split('@').first;
    if (displayName.isEmpty) displayName = email;

    final parts = displayName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : ' ';

    final profileRes = await SupabaseService.safeFrom('profiles', tenantId)
        .insert({
          'email': email,
          'first_name': firstName,
          'last_name': lastName.isEmpty ? ' ' : lastName,
          'name': displayName,
          'status': 'pending',
          'role': 'property_owner',
          'roles': [],
        })
        .select('id')
        .single();
    final newProfileId = (profileRes as Map)['id']?.toString();
    if (newProfileId == null || newProfileId.isEmpty) {
      throw StateError('admin.owners_error_profile_not_created');
    }

    final invPayload = <String, dynamic>{
      'profile_id': newProfileId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': 'property_owner',
      'roles': [],
    };
    final invRes = await SupabaseService.safeFrom('invitations', tenantId)
        .insert(invPayload)
        .select('id')
        .single();
    final newInvitationId = (invRes as Map)['id']?.toString();
    if (newInvitationId == null || newInvitationId.isEmpty) {
      throw StateError('admin.owners_error_invitation_not_created');
    }

    await SupabaseService.safeFrom('clients', tenantId)
        .update({'profile_id': newProfileId})
        .eq('id', client.id);

    targetProfileId = newProfileId;
    inviteLink = origin.trim().isNotEmpty
        ? '$origin/#/invite?token=$newInvitationId'
        : null;
  }

  await _ensureOwnerLinked(
    apartmentId: apartmentId,
    ownerId: targetProfileId,
    tenantId: tenantId,
  );

  return inviteLink;
}

  /// Přidá propojení majitel–byt. Volá admin; RLS kontroluje tenant_id.
  /// Pokud existuje soft-deleted záznam stejné dvojice, obnoví ho místo nového INSERT.
  static Future<void> addOwner({
    required String apartmentId,
    required String ownerId,
    required String tenantId,
  }) async {
    await _ensureOwnerLinked(
      apartmentId: apartmentId,
      ownerId: ownerId,
      tenantId: tenantId,
    );
  }

  /// Odebere propojení – soft delete (nastavení deleted_at).
  static Future<void> removeOwner({
    required String apartmentOwnersId,
    required String tenantId,
  }) async {
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    await SupabaseService.safeFrom('apartment_owners', tenantId)
        .update({'deleted_at': deletedAt})
        .eq('id', apartmentOwnersId);
  }

  /// Nastaví jednoho majitele jako hlavního plátce (is_primary_billing) pro daný apartmán.
  ///
  /// PROČ "JEN JEDEN": U spoluvlastnictví smí být hlavní plátce pouze jeden – fakturace
  /// (paušál i úkoly) jde jen jemu. Nejprve nastavíme is_primary_billing = false všem
  /// záznamům daného bytu, pak true vybranému záznamu.
  static Future<void> setPrimaryBillingOwner({
    required String tenantId,
    required String apartmentId,
    required String apartmentOwnersRecordId,
  }) async {
    await SupabaseService.safeFrom('apartment_owners', tenantId)
        .update({'is_primary_billing': false})
        .eq('apartment_id', apartmentId)
        .isFilter('deleted_at', null);
    await SupabaseService.safeFrom('apartment_owners', tenantId)
        .update({'is_primary_billing': true})
        .eq('id', apartmentOwnersRecordId);
  }
}
