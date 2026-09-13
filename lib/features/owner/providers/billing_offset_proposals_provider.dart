import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/owner_view_impersonation_providers.dart';
import 'package:falconest/features/admin/providers/admin_finance_providers.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';
import 'package:falconest/features/owner/models/billing_snapshot_offset_proposal.dart';
import 'package:falconest/features/owner/providers/owner_billing_provider.dart';
import 'package:falconest/features/owner/providers/owner_cash_providers.dart';
import 'package:falconest/features/owner/repositories/billing_offset_proposals_repository.dart';

/// Repozitář návrhů doplatku – singleton bez stavu.
final billingOffsetProposalsRepositoryProvider =
    Provider<BillingOffsetProposalsRepository>((ref) {
  return const BillingOffsetProposalsRepository();
});

/// Aktivní návrh (`pending_owner`) pro jednu fakturu – Admin i Owner UI.
final ownerPendingOffsetProposalProvider = FutureProvider.autoDispose
    .family<BillingSnapshotOffsetProposal?, String>((ref, snapshotId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty || snapshotId.trim().isEmpty) {
    return null;
  }
  return BillingOffsetProposalsRepository.getPendingForSnapshot(
    tenantId: tenantId,
    billingSnapshotId: snapshotId,
  );
});

/// Všechny čekající návrhy přihlášeného majitele (dashboard banner – volitelné).
final ownerAllPendingOffsetProposalsProvider =
    FutureProvider.autoDispose<List<BillingSnapshotOffsetProposal>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final profileId = ref.watch(effectiveProfileIdProvider);
  if (tenantId == null ||
      tenantId.isEmpty ||
      profileId == null ||
      profileId.isEmpty) {
    return [];
  }
  return BillingOffsetProposalsRepository.listPendingForOwner(
    tenantId: tenantId,
    ownerProfileId: profileId,
  );
});

/// Po změně návrhu nebo zápočtu obnoví závislé providery.
void invalidateBillingOffsetProposalScope(
  WidgetRef ref, {
  required String snapshotId,
  BillingMonthParam? billingMonth,
}) {
  ref.invalidate(ownerPendingOffsetProposalProvider(snapshotId));
  ref.invalidate(ownerAllPendingOffsetProposalsProvider);
  ref.invalidate(ownerBillingSnapshotsProvider);
  ref.invalidate(ownerAvailableBalanceProvider);
  ref.invalidate(ownerCashRequestsProvider);
  ref.invalidate(adminOwnerCashRequestsProvider);
  if (billingMonth != null) {
    ref.invalidate(billingReportProvider(billingMonth));
  }
}
