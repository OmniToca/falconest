import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/owner/models/admin_owner_cash_disposition_row.dart';
import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';

/// Všechny žádosti majitelů o výplatu / dispozici hotovosti v aktuálním tenantovi.
///
/// PROČ: Admin a dispečink vyřizují frontu v modulu Finance; data jdou z [OwnerCashDispositionRepository.getRequestsForTenant]
/// (RLS povolí staff s rolí mimo `property_owner`).
final adminOwnerCashRequestsProvider =
    FutureProvider.autoDispose<List<AdminOwnerCashDispositionRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  return OwnerCashDispositionRepository.getRequestsForTenant(tenantId: tenantId);
});
