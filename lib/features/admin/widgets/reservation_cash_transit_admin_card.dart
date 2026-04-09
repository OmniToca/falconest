import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/repositories/cash/reservation_cash_transit_repository.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';

/// Karta „průtoková hotovost“ v detailu rezervace (admin).
class ReservationCashTransitAdminCard extends ConsumerWidget {
  const ReservationCashTransitAdminCard({super.key, required this.reservationId});

  final String reservationId;

  static ({Color bg, Color fg, Color border, IconData icon}) _visuals(
    BuildContext context,
    ReservationCashTransitPhase phase,
  ) {
    final c = context.colors;
    final x = context.customColors;
    return switch (phase) {
      ReservationCashTransitPhase.awaitingCollection => (
          bg: c.surfaceContainerHighest,
          fg: c.onSurfaceVariant,
          border: c.outlineVariant,
          icon: Icons.schedule_outlined,
        ),
      ReservationCashTransitPhase.withWorker => (
          bg: x.warningSubtle,
          fg: c.onSurface,
          border: x.warning.withValues(alpha: 0.45),
          icon: Icons.person_pin_circle_outlined,
        ),
      ReservationCashTransitPhase.atAgencyVault => (
          bg: x.infoSubtle,
          fg: c.onSurface,
          border: x.info.withValues(alpha: 0.4),
          icon: Icons.account_balance_wallet_outlined,
        ),
      ReservationCashTransitPhase.settledToOwner => (
          bg: x.successSubtle,
          fg: x.success,
          border: x.success.withValues(alpha: 0.35),
          icon: Icons.verified_outlined,
        ),
      ReservationCashTransitPhase.notApplicable => (
          bg: c.surfaceContainerHighest,
          fg: c.onSurfaceVariant,
          border: c.outlineVariant,
          icon: Icons.payments_outlined,
        ),
    };
  }

  static String? _formatMoney(
    WidgetRef ref,
    double? amount,
    String currencyCode,
  ) {
    if (amount == null) return null;
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    if (currencies.isEmpty) {
      return '${amount.toStringAsFixed(2)} $currencyCode';
    }
    return CurrencyService.formatAmountInTargetCurrency(
      amount,
      currencyCode,
      currencies,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rid = reservationId.trim();
    if (rid.isEmpty) return const SizedBox.shrink();

    final snapAsync = ref.watch(reservationCashTransitProvider(rid));

    return snapAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (snap) {
        if (snap.phase == ReservationCashTransitPhase.notApplicable) {
          return const SizedBox.shrink();
        }

        final v = _visuals(context, snap.phase);
        final phaseLabel = tr(snap.phase.labelTranslationKey);
        final canSettle = ref.watch(authNotifierProvider.select((n) {
          final s = n.state;
          return s.isAdminOrManager || s.isSuperAdmin;
        }));

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Material(
            color: v.bg,
            borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
                border: Border.all(color: v.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(v.icon, color: v.fg, size: 28),
                      const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              tr('finance.cash_transit_card_title'),
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phaseLabel,
                              style: context.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: v.fg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AmountLines(snap: snap),
                  if (snap.phase == ReservationCashTransitPhase.settledToOwner &&
                      snap.settledAt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      tr(
                        'finance.cash_transit_settled_detail',
                        namedArgs: {
                          'date': DateFormat.yMMMd(
                            context.locale.toString(),
                          ).add_Hm().format(snap.settledAt!.toLocal()),
                        },
                      ),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (snap.phase == ReservationCashTransitPhase.atAgencyVault &&
                      canSettle) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => _SettleTransitCashSheet.show(
                        context,
                        ref,
                        reservationId: rid,
                        snapshot: snap,
                      ),
                      icon: const Icon(Icons.savings_outlined, size: 20),
                      label: Text(tr('finance.cash_transit_settle_btn')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AmountLines extends ConsumerWidget {
  const _AmountLines({required this.snap});

  final ReservationCashTransitSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = <Widget>[];
    final planned = ReservationCashTransitAdminCard._formatMoney(
      ref,
      snap.plannedAmount,
      snap.currencyCode,
    );
    if (planned != null) {
      lines.add(
        Text(
          '${tr('finance.cash_transit_planned_label')}: $planned',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    final collected = ReservationCashTransitAdminCard._formatMoney(
      ref,
      snap.collectedTotal,
      snap.currencyCode,
    );
    if (collected != null) {
      lines.add(
        Text(
          '${tr('finance.cash_transit_collected_label')}: $collected',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    final settled = ReservationCashTransitAdminCard._formatMoney(
      ref,
      snap.settledAmount,
      snap.currencyCode,
    );
    if (settled != null &&
        snap.phase == ReservationCashTransitPhase.settledToOwner) {
      lines.add(
        Text(
          '${tr('finance.cash_transit_settled_amount_label')}: $settled',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          lines[i],
        ],
      ],
    );
  }
}

/// Spodní list / dialog pro zápis settlementu.
class _SettleTransitCashSheet {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String reservationId,
    required ReservationCashTransitSnapshot snapshot,
  }) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final profileId = ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        profileId == null ||
        profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('finance.cash_transit_settle_error_auth'))),
      );
      return;
    }

    final defaultAmount = snapshot.collectedTotal ?? snapshot.plannedAmount ?? 0.0;
    final amountController = TextEditingController(
      text: defaultAmount > 0 ? defaultAmount.toStringAsFixed(2) : '',
    );
    final noteController = TextEditingController();
    var submitting = false;

    final currency =
        ref.read(currentTenantCurrencyProvider).valueOrNull?.trim().isNotEmpty == true
            ? ref.read(currentTenantCurrencyProvider).valueOrNull!.trim().toUpperCase()
            : (ref.read(authNotifierProvider).state.preferredCurrency
                        ?.trim()
                        .isNotEmpty ==
                    true
                ? ref.read(authNotifierProvider).state.preferredCurrency!.trim().toUpperCase()
                : snapshot.currencyCode);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sm + AppSpacing.xs),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.md,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('finance.cash_transit_settle_title'),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    tr('finance.cash_transit_settle_body'),
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: amountController,
                    enabled: !submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr('finance.cash_transit_settle_amount_label'),
                      suffixText: currency,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                  TextField(
                    controller: noteController,
                    enabled: !submitting,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: tr('finance.cash_transit_settle_note_label'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final raw = amountController.text.trim().replaceAll(',', '.');
                            final amt = double.tryParse(raw);
                            if (amt == null || amt <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr('finance.cash_transit_settle_amount_invalid'),
                                  ),
                                ),
                              );
                              return;
                            }
                            setModalState(() => submitting = true);
                            try {
                              await ReservationCashTransitRepository.settleTransitCash(
                                tenantId: tenantId,
                                reservationId: reservationId,
                                createdByProfileId: profileId,
                                amount: amt,
                                currency: currency,
                                note: noteController.text,
                              );
                              if (context.mounted) {
                                ref.invalidate(
                                  reservationCashTransitProvider(reservationId),
                                );
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tr('finance.cash_transit_settle_success'),
                                    ),
                                    backgroundColor: context.customColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => submitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tr('finance.cash_transit_settle_error'),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(tr('finance.cash_transit_settle_confirm_btn')),
                  ),
                  TextButton(
                    onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                    child: Text(tr('common.cancel')),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    amountController.dispose();
    noteController.dispose();
  }
}
