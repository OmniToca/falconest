import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Provider načítající seznam klientů z tabulky [clients].
///
/// Filtr podle tenant_id zajišťuje multi-tenant izolaci.
/// Soft delete: ignorujeme záznamy s deleted_at IS NOT NULL.
/// Používá se na obrazovce Klienti a pro dropdown při vytváření externích úkolů.
final clientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final response = await SupabaseService.client
      .from('clients')
      .select('id, tenant_id, name, email, phone, client_type, profile_id, created_at, deleted_at')
      .eq('tenant_id', tenantId)
      .isFilter('deleted_at', null)
      .order('name');

  return (response as List)
      .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
      .toList();
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

    await SupabaseService.client.from('clients').insert(map);
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
    };

    await SupabaseService.client
        .from('clients')
        .update(map)
        .eq('id', client.id)
        .eq('tenant_id', tenantId);
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
    FutureProvider.family<Map<String, dynamic>?, String>((ref, profileId) async {
  if (profileId.isEmpty) return null;

  final res = await SupabaseService.client
      .from('profiles')
      .select('status, last_sign_in_at')
      .eq('id', profileId)
      .maybeSingle();

  if (res == null) return null;
  final map = res as Map<String, dynamic>;
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

    await SupabaseService.client
        .from('clients')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', clientId)
        .eq('tenant_id', tenantId);
  };
});
