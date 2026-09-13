import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/owner/models/billing_snapshot_offset_proposal.dart';
import 'package:falconest/features/owner/providers/billing_offset_proposals_provider.dart';
import 'package:falconest/features/owner/providers/owner_cash_providers.dart';
import 'package:falconest/features/owner/repositories/billing_offset_proposals_repository.dart';
import 'package:falconest/features/owner/widgets/owner_portal_ui.dart';
import 'package:falconest/features/owner/widgets/owner_read_only_gate.dart';

/// Interaktivní karta pro schválení/zamítnutí návrhu doplatku – Owner portál Fáze 3.3.
class BillingOffsetProposalOwnerCard extends ConsumerStatefulWidget {
  const BillingOffsetProposalOwnerCard({
    super.key,
    required this.snapshotId,
    required this.currency,
  });

  final String snapshotId;
  final String currency;

  @override
  ConsumerState<BillingOffsetProposalOwnerCard> createState() =>
      _BillingOffsetProposalOwnerCardState();
}

class _BillingOffsetProposalOwnerCardState
    extends ConsumerState<BillingOffsetProposalOwnerCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final proposalAsync =
        ref.watch(ownerPendingOffsetProposalProvider(widget.snapshotId));

    return proposalAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (proposal) {
        if (proposal == null || !proposal.isPendingOwner) {
          return const SizedBox.shrink();
        }
        return _buildCard(context, proposal);
      },
    );
  }

  Widget _buildCard(BuildContext context, BillingSnapshotOffsetProposal proposal) {
    final cs = context.colors;
    final tt = Theme.of(context).textTheme;
    final balanceAsync = ref.watch(ownerAvailableBalanceProvider);
    final availableBalance = balanceAsync.valueOrNull ?? 0.0;
    final balanceAfter =
        (availableBalance - proposal.proposedAmount).clamp(0.0, double.infinity);
    final amountStr =
        '${proposal.proposedAmount.toStringAsFixed(2)} ${proposal.currency}';
    final remainingStr =
        '${balanceAfter.toStringAsFixed(2)} ${proposal.currency}';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(kOwnerPortalCardRadius),
          border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: cs.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'owner.billing_offset_proposal_owner_body'.tr(
                      namedArgs: {
                        'amount': amountStr,
                        'remaining': remainingStr,
                      },
                    ),
                    style: tt.bodyMedium?.copyWith(
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OwnerReadOnlyGate(
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _respond(context, proposal.id, 'approve'),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'owner.billing_offset_proposal_owner_approve'.tr(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _respond(context, proposal.id, 'reject'),
                      child: Text(
                        'owner.billing_offset_proposal_owner_reject'.tr(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    String proposalId,
    String action,
  ) async {
    setState(() => _busy = true);
    try {
      final result = await BillingOffsetProposalsRepository.respondProposal(
        proposalId: proposalId,
        action: action,
      );
      invalidateBillingOffsetProposalScope(
        ref,
        snapshotId: widget.snapshotId,
      );
      if (!context.mounted) return;
      final messageKey = action == 'approve'
          ? 'owner.billing_offset_proposal_approve_success'
          : 'owner.billing_offset_proposal_reject_success';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageKey.tr())),
      );
      if (action == 'approve' &&
          result.paymentStatus == 'cash_offset' &&
          context.mounted) {
        // PROČ: Majitel vidí okamžitě nový stav faktury po atomickém RPC.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'owner.billing_offset_proposal_approve_paid'.tr(
                namedArgs: {
                  'amount':
                      '${(result.appliedAmount ?? 0).toStringAsFixed(2)} ${widget.currency}',
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Dočasně: surová DB/PostgREST zpráva pro přesnou diagnostiku (místo generického i18n).
        final diagnostic =
            BillingOffsetProposalsRepository.diagnosticMessageFrom(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(diagnostic),
            duration: const Duration(seconds: 14),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
