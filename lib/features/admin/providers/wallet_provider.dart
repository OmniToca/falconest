import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Stream provider pro aktuální zůstatek kreditů (balance) v tenant_wallets.
///
/// Poslouchá změny v reálném čase přes Supabase Realtime. Při chybějícím tenant_id
/// vrací 0. Tabulka tenant_wallets musí být v supabase_realtime publikaci (Dashboard → Database → Replication).
final walletBalanceProvider = StreamProvider<int>((ref) {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    return Stream<int>.value(0);
  }

  return SupabaseService.safeFrom('tenant_wallets', tenantId)
      .stream(primaryKey: ['tenant_id'])
      .map((List<Map<String, dynamic>> list) {
        final ourRow = list.where((r) => r['tenant_id']?.toString() == tenantId).firstOrNull ?? list.firstOrNull;
        if (ourRow == null) return 0;
        final raw = ourRow['balance'];
        if (raw is int) return raw;
        return int.tryParse(raw?.toString() ?? '0') ?? 0;
      });
});
