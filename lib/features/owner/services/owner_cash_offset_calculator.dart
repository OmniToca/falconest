import 'dart:math' as math;

import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';

/// Výsledek výpočtu zápočtu hotovosti na fakturu – sdílený Admin UI i repozitář.
///
/// PROČ: Jedna pure funkce zabraňuje rozporu mezi náhledem v dialogu a skutečným zápisem.
class OwnerCashOffsetPlan {
  const OwnerCashOffsetPlan({
    required this.invoiceDue,
    required this.ownerPool,
    required this.requestRemaining,
    required this.existingOffsetAmount,
    required this.amountToApply,
    required this.remainingInvoiceDue,
    required this.derivedPaymentStatus,
    required this.blocked,
    this.blockReasonL10nKey,
  });

  /// Celková částka k úhradě na faktuře (final_to_invoice).
  final double invoiceDue;

  /// Fyzický pool majitele = Σ owner_cash_transit_settlements.amount (bez odečtu rezervací).
  final double ownerPool;

  /// Zbývající objem schválené žádosti invoice_credit.
  final double requestRemaining;

  /// Již dříve zapsaný zápočet na tomto snapshotu.
  final double existingOffsetAmount;

  /// Kolik se skutečně strhne při tomto zápočtu.
  final double amountToApply;

  /// Kolik zbude doplatit po tomto zápočtu.
  final double remainingInvoiceDue;

  /// `cash_offset` nebo `partially_paid` – odvozeno automaticky.
  final String derivedPaymentStatus;

  /// True = nelze provést zápočet (amountToApply ≈ 0).
  final bool blocked;

  /// Klíč pro `.tr()` – např. insufficient pool.
  final String? blockReasonL10nKey;

  bool get isPartial =>
      derivedPaymentStatus ==
      BillingSnapshotOffsetPaymentStatusValues.partiallyPaid;

  bool get isFull =>
      derivedPaymentStatus == BillingSnapshotOffsetPaymentStatusValues.cashOffset;
}

/// Pure logika zápočtu – bez I/O, snadno testovatelná.
abstract final class OwnerCashOffsetCalculator {
  OwnerCashOffsetCalculator._();

  static const _eps = 1e-9;

  /// Vypočte plán zápočtu.
  ///
  /// [ownerPool] = fyzický součet settlementů (ne „dostupný zůstatek“ po rezervacích).
  /// [existingOffsetAmount] = již uhrazeno zápočtem na stejném snapshotu (doplňkový zápočet kumuluje).
  static OwnerCashOffsetPlan compute({
    required double invoiceDue,
    required double ownerPool,
    required double requestRemaining,
    double existingOffsetAmount = 0,
  }) {
    final due = math.max(0.0, invoiceDue);
    final pool = math.max(0.0, ownerPool);
    final reqRem = math.max(0.0, requestRemaining);
    final priorOffset = math.max(0.0, existingOffsetAmount);

    final invoiceRemaining = math.max(0.0, due - priorOffset);

    if (invoiceRemaining <= _eps) {
      return OwnerCashOffsetPlan(
        invoiceDue: due,
        ownerPool: pool,
        requestRemaining: reqRem,
        existingOffsetAmount: priorOffset,
        amountToApply: 0,
        remainingInvoiceDue: 0,
        derivedPaymentStatus: BillingSnapshotOffsetPaymentStatusValues.cashOffset,
        blocked: true,
        blockReasonL10nKey:
            'admin.finance.billing_snapshot_offset_already_settled',
      );
    }

    if (reqRem <= _eps) {
      return OwnerCashOffsetPlan(
        invoiceDue: due,
        ownerPool: pool,
        requestRemaining: reqRem,
        existingOffsetAmount: priorOffset,
        amountToApply: 0,
        remainingInvoiceDue: invoiceRemaining,
        derivedPaymentStatus: BillingSnapshotOffsetPaymentStatusValues.partiallyPaid,
        blocked: true,
        blockReasonL10nKey:
            'admin.finance.billing_snapshot_offset_no_remaining',
      );
    }

    if (pool <= _eps) {
      return OwnerCashOffsetPlan(
        invoiceDue: due,
        ownerPool: pool,
        requestRemaining: reqRem,
        existingOffsetAmount: priorOffset,
        amountToApply: 0,
        remainingInvoiceDue: invoiceRemaining,
        derivedPaymentStatus: BillingSnapshotOffsetPaymentStatusValues.partiallyPaid,
        blocked: true,
        blockReasonL10nKey:
            'admin.finance.billing_snapshot_offset_insufficient_pool',
      );
    }

    final amountToApply = math.min(invoiceRemaining, math.min(reqRem, pool));
    final remainingAfter = math.max(0.0, invoiceRemaining - amountToApply);

    if (amountToApply <= _eps) {
      return OwnerCashOffsetPlan(
        invoiceDue: due,
        ownerPool: pool,
        requestRemaining: reqRem,
        existingOffsetAmount: priorOffset,
        amountToApply: 0,
        remainingInvoiceDue: invoiceRemaining,
        derivedPaymentStatus: BillingSnapshotOffsetPaymentStatusValues.partiallyPaid,
        blocked: true,
        blockReasonL10nKey:
            'admin.finance.billing_snapshot_offset_insufficient_pool',
      );
    }

    final derivedStatus = remainingAfter <= _eps
        ? BillingSnapshotOffsetPaymentStatusValues.cashOffset
        : BillingSnapshotOffsetPaymentStatusValues.partiallyPaid;

    return OwnerCashOffsetPlan(
      invoiceDue: due,
      ownerPool: pool,
      requestRemaining: reqRem,
      existingOffsetAmount: priorOffset,
      amountToApply: amountToApply,
      remainingInvoiceDue: remainingAfter,
      derivedPaymentStatus: derivedStatus,
      blocked: false,
    );
  }
}
