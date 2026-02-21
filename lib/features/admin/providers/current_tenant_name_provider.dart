import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Model aktuálního tenanta včetně is_active – pro real-time vyhazovač (Kill-Switch).
class CurrentTenantDetail {
  const CurrentTenantDetail({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;
}

/// Načte jeden tenant (id, name, is_active) z DB.
Future<CurrentTenantDetail?> _fetchCurrentTenant(String tenantId) async {
  try {
    final res = await SupabaseService.client
        .from('tenants')
        .select('id, name, is_active')
        .eq('id', tenantId)
        .maybeSingle();
    if (res == null) return null;
    final map = res as Map;
    final id = map['id']?.toString() ?? '';
    final name = (map['name'] as String? ?? '').trim();
    final isActive = map['is_active'] == true || map['is_active'] == 'true';
    if (id.isEmpty) return null;
    return CurrentTenantDetail(id: id, name: name, isActive: isActive);
  } catch (_) {
    return null;
  }
}

/// Aktuální tenant s Realtime: při změně záznamu v tabulce tenants (UPDATE)
/// se stav automaticky znovu načte. Slouží pro okamžitý redirect na /suspended
/// když Super Admin vypne agenturu (is_active -> false).
final currentTenantWithRealtimeProvider =
    AsyncNotifierProvider<CurrentTenantWithRealtimeNotifier, CurrentTenantDetail?>(
  CurrentTenantWithRealtimeNotifier.new,
);

class CurrentTenantWithRealtimeNotifier extends AsyncNotifier<CurrentTenantDetail?> {
  RealtimeChannel? _channel;

  @override
  Future<CurrentTenantDetail?> build() async {
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      _channel?.unsubscribe();
      _channel = null;
      return null;
    }

    final tenant = await _fetchCurrentTenant(tenantId);
    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('tenant-realtime-$tenantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tenants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: tenantId,
          ),
          callback: (_) async {
            final t = await _fetchCurrentTenant(tenantId);
            state = AsyncValue.data(t);
          },
        )
        .subscribe();

    ref.onDispose(() {
      _channel?.unsubscribe();
      _channel = null;
    });

    return tenant;
  }
}

/// Provider vracející název aktuální agentury (tenanta).
final currentTenantNameProvider = FutureProvider<String>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return '';

  try {
    final res = await SupabaseService.client
        .from('tenants')
        .select('name')
        .eq('id', tenantId)
        .maybeSingle();
    if (res != null) {
      return (res['name'] as String? ?? '').trim();
    }
  } catch (_) {}
  return '';
});

/// Oznámení systému (system_announcement) pro aktuálního tenanta – pro Megafon.
/// Null nebo prázdný řetězec = nezobrazovat pruh.
final currentTenantAnnouncementProvider = FutureProvider<String?>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return null;

  try {
    final res = await SupabaseService.client
        .from('tenants')
        .select('system_announcement')
        .eq('id', tenantId)
        .maybeSingle();
    if (res != null) {
      final v = res['system_announcement'] as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
  } catch (_) {}
  return null;
});
