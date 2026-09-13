import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';
import 'package:falconest/features/owner/services/owner_cash_offset_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OwnerCashOffsetCalculator', () {
    test('plný zápočet když pool pokryje celou fakturu', () {
      final plan = OwnerCashOffsetCalculator.compute(
        invoiceDue: 120,
        ownerPool: 200,
        requestRemaining: 240,
      );
      expect(plan.amountToApply, 120);
      expect(plan.remainingInvoiceDue, 0);
      expect(plan.derivedPaymentStatus,
          BillingSnapshotOffsetPaymentStatusValues.cashOffset);
      expect(plan.blocked, isFalse);
    });

    test('částečný zápočet když pool < faktura (120 / 240)', () {
      final plan = OwnerCashOffsetCalculator.compute(
        invoiceDue: 240,
        ownerPool: 120,
        requestRemaining: 240,
      );
      expect(plan.amountToApply, 120);
      expect(plan.remainingInvoiceDue, 120);
      expect(plan.derivedPaymentStatus,
          BillingSnapshotOffsetPaymentStatusValues.partiallyPaid);
      expect(plan.blocked, isFalse);
    });

    test('blokace při nulovém poolu', () {
      final plan = OwnerCashOffsetCalculator.compute(
        invoiceDue: 240,
        ownerPool: 0,
        requestRemaining: 240,
      );
      expect(plan.blocked, isTrue);
      expect(plan.amountToApply, 0);
      expect(plan.blockReasonL10nKey,
          'admin.finance.billing_snapshot_offset_insufficient_pool');
    });

    test('limit podle zbývající žádosti', () {
      final plan = OwnerCashOffsetCalculator.compute(
        invoiceDue: 500,
        ownerPool: 500,
        requestRemaining: 80,
      );
      expect(plan.amountToApply, 80);
      expect(plan.remainingInvoiceDue, 420);
      expect(plan.isPartial, isTrue);
    });

    test('doplňkový zápočet dorovná zbývající fakturu po prvním zápočtu', () {
      final plan = OwnerCashOffsetCalculator.compute(
        invoiceDue: 240,
        ownerPool: 120,
        requestRemaining: 120,
        existingOffsetAmount: 120,
      );
      expect(plan.blocked, isFalse);
      expect(plan.amountToApply, 120);
      expect(plan.remainingInvoiceDue, 0);
      expect(plan.isFull, isTrue);
    });
  });
}
