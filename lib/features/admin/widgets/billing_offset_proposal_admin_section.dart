import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';
import 'package:falconest/features/owner/models/billing_snapshot_offset_proposal.dart';
import 'package:falconest/features/owner/providers/billing_offset_proposals_provider.dart';
import 'package:falconest/features/owner/repositories/billing_offset_proposals_repository.dart';

/// Admin UI – návrh doplatku ze zálohy majitele u `partially_paid` faktury.
///
/// PROČ: Approval Loop Fáze 3.2 – dispečer navrhne, majitel schválí v Owner portálu.
class BillingOffsetProposalAdminSection extends ConsumerWidget {
  const BillingOffsetProposalAdminSection({
    super.key,
    required this.group,
    required this.currency,
    required this.billingMonth,
  });

  final BillingGroup group;
  final String currency;
  final BillingMonthParam billingMonth;

  static const _eps = 1e-9;

  bool get _isEligible {
    if ((group.billingSnapshotId ?? '').isEmpty) return false;
    if (group.groupKey == 'external') return false;
    return group.paymentStatus.trim().toLowerCase() == 'partially_paid';
  }

  double get _remainingDue =>
      (group.finalToInvoice - group.offsetAmount).clamp(0.0, double.infinity);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isEligible || _remainingDue <= _eps) {
      return const SizedBox.shrink();
    }

    final snapshotId = group.billingSnapshotId!;
    final proposalAsync = ref.watch(ownerPendingOffsetProposalProvider(snapshotId));

    return proposalAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, st) => const SizedBox.shrink(),
      data: (proposal) {
        if (proposal != null && proposal.isPendingOwner) {
          return _PendingProposalBanner(
            proposal: proposal,
            currency: currency,
            onCancel: () => _cancelProposal(context, ref, proposal.id, snapshotId),
          );
        }
        return _ProposeActionRow(
          remainingDue: _remainingDue,
          currency: currency,
          onPropose: () => _propose(context, ref, snapshotId),
        );
      },
    );
  }

  Future<void> _propose(
    BuildContext context,
    WidgetRef ref,
    String snapshotId,
  ) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final adminProfileId = ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        adminProfileId == null ||
        adminProfileId.isEmpty) {
      return;
    }

    try {
      final draft =
          await BillingOffsetProposalsRepository.prepareDraftForBillingClient(
        tenantId: tenantId,
        billingClientId: group.groupKey,
        finalToInvoice: group.finalToInvoice,
        existingOffsetAmount: group.offsetAmount,
        currencyCode: currency,
      );

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('admin.finance.billing_offset_proposal_confirm_title'.tr()),
          content: Text(
            'admin.finance.billing_offset_proposal_confirm_body'.tr(
              namedArgs: {
                'amount': _fmt(draft.proposedAmount, currency),
                'pool': _fmt(draft.availableBalance, currency),
                'remaining': _fmt(draft.balanceAfterProposal, currency),
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('common.confirm'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      await BillingOffsetProposalsRepository.createProposal(
        tenantId: tenantId,
        billingSnapshotId: snapshotId,
        ownerProfileId: draft.ownerProfileId,
        settlementId: draft.settlementId,
        proposedAmount: draft.proposedAmount,
        currency: draft.currency,
        proposedByProfileId: adminProfileId,
      );

      invalidateBillingOffsetProposalScope(
        ref,
        snapshotId: snapshotId,
        billingMonth: billingMonth,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'admin.finance.billing_offset_proposal_create_success'.tr(),
            ),
          ),
        );
      }
    } on BillingOffsetProposalException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.l10nKey.tr())),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'admin.finance.billing_offset_proposal_create_error'.tr(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancelProposal(
    BuildContext context,
    WidgetRef ref,
    String proposalId,
    String snapshotId,
  ) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.finance.billing_offset_proposal_cancel_title'.tr()),
        content: Text('admin.finance.billing_offset_proposal_cancel_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await BillingOffsetProposalsRepository.cancelProposal(
        tenantId: tenantId,
        proposalId: proposalId,
      );
      invalidateBillingOffsetProposalScope(
        ref,
        snapshotId: snapshotId,
        billingMonth: billingMonth,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'admin.finance.billing_offset_proposal_cancel_success'.tr(),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'admin.finance.billing_offset_proposal_create_error'.tr(),
            ),
          ),
        );
      }
    }
  }

  String _fmt(double v, String cur) => '${v.toStringAsFixed(2)} $cur';
}

class BillingOffsetProposalAdminChip extends ConsumerWidget {
  const BillingOffsetProposalAdminChip({
    super.key,
    required this.snapshotId,
  });

  final String snapshotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalAsync = ref.watch(ownerPendingOffsetProposalProvider(snapshotId));
    return proposalAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (proposal) {
        if (proposal == null || !proposal.isPendingOwner) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Chip(
            visualDensity: VisualDensity.compact,
            label: Text(
              'admin.finance.billing_offset_proposal_waiting_owner'.tr(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            avatar: Icon(
              Icons.hourglass_top_rounded,
              size: 16,
              color: context.colors.tertiary,
            ),
          ),
        );
      },
    );
  }
}

class _ProposeActionRow extends StatelessWidget {
  const _ProposeActionRow({
    required this.remainingDue,
    required this.currency,
    required this.onPropose,
  });

  final double remainingDue;
  final String currency;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'admin.finance.billing_offset_proposal_section_hint'.tr(
                namedArgs: {
                  'remaining': '${remainingDue.toStringAsFixed(2)} $currency',
                },
              ),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onPropose,
                icon: const Icon(Icons.send_outlined, size: 20),
                label: Text(
                  'admin.finance.billing_offset_proposal_action_propose'.tr(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingProposalBanner extends StatelessWidget {
  const _PendingProposalBanner({
    required this.proposal,
    required this.currency,
    required this.onCancel,
  });

  final BillingSnapshotOffsetProposal proposal;
  final String currency;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = Theme.of(context).textTheme;
    final amount = proposal.proposedAmount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top_rounded, color: cs.tertiary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'admin.finance.billing_offset_proposal_waiting_owner'.tr(),
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'admin.finance.billing_offset_proposal_waiting_detail'.tr(
                      namedArgs: {
                        'amount': '${amount.toStringAsFixed(2)} $currency',
                      },
                    ),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: Text('admin.finance.billing_offset_proposal_cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
