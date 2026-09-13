/// Řádek tabulky `billing_snapshot_offset_proposals` – návrh doplatku faktury ze zálohy.
///
/// PROČ: Approval Loop mezi dispečerem a majitelem; schválení probíhá přes DB RPC,
/// ne přímým UPDATE z Flutteru.
class BillingSnapshotOffsetProposal {
  const BillingSnapshotOffsetProposal({
    required this.id,
    required this.tenantId,
    required this.billingSnapshotId,
    required this.ownerProfileId,
    required this.settlementId,
    required this.proposedAmount,
    this.appliedAmount,
    required this.currency,
    required this.status,
    required this.proposedByProfileId,
    this.dispositionRequestId,
    this.ownerRespondedAt,
    this.ownerRejectionNote,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String billingSnapshotId;
  final String ownerProfileId;
  final String settlementId;
  final double proposedAmount;
  final double? appliedAmount;
  final String currency;

  /// `pending_owner` | `applied` | `rejected_by_owner` | `cancelled_by_admin` | `stale`
  final String status;
  final String proposedByProfileId;
  final String? dispositionRequestId;
  final DateTime? ownerRespondedAt;
  final String? ownerRejectionNote;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPendingOwner => status == BillingSnapshotOffsetProposalStatus.pendingOwner;

  factory BillingSnapshotOffsetProposal.fromJson(Map<String, dynamic> json) {
    return BillingSnapshotOffsetProposal(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      billingSnapshotId: json['billing_snapshot_id']?.toString() ?? '',
      ownerProfileId: json['owner_profile_id']?.toString() ?? '',
      settlementId: json['settlement_id']?.toString() ?? '',
      proposedAmount: _amount(json['proposed_amount']),
      appliedAmount: json['applied_amount'] == null
          ? null
          : _amount(json['applied_amount']),
      currency: (json['currency'] as String?)?.trim().isNotEmpty == true
          ? (json['currency'] as String).trim()
          : 'EUR',
      status: (json['status'] as String?)?.trim() ?? '',
      proposedByProfileId: json['proposed_by_profile_id']?.toString() ?? '',
      dispositionRequestId: json['disposition_request_id']?.toString(),
      ownerRespondedAt: _dateTime(json['owner_responded_at']),
      ownerRejectionNote: json['owner_rejection_note'] as String?,
      adminNotes: json['admin_notes'] as String?,
      createdAt: _dateTime(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _dateTime(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  static double _amount(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

/// Konstanty sloupce `status` – odpovídají CHECK v migraci `20260828160000`.
abstract final class BillingSnapshotOffsetProposalStatus {
  static const pendingOwner = 'pending_owner';
  static const applied = 'applied';
  static const rejectedByOwner = 'rejected_by_owner';
  static const cancelledByAdmin = 'cancelled_by_admin';
  static const stale = 'stale';
}

/// Výsledek RPC `respond_billing_offset_proposal`.
class BillingOffsetProposalRespondResult {
  const BillingOffsetProposalRespondResult({
    required this.ok,
    required this.action,
    required this.proposalId,
    required this.status,
    this.appliedAmount,
    this.paymentStatus,
    this.remainingInvoiceDue,
    this.dispositionRequestId,
  });

  final bool ok;
  final String action;
  final String proposalId;
  final String status;
  final double? appliedAmount;
  final String? paymentStatus;
  final double? remainingInvoiceDue;
  final String? dispositionRequestId;

  factory BillingOffsetProposalRespondResult.fromJson(Map<String, dynamic> json) {
    double? applied;
    final rawApplied = json['applied_amount'];
    if (rawApplied is num) {
      applied = rawApplied.toDouble();
    } else if (rawApplied != null) {
      applied = double.tryParse(rawApplied.toString());
    }
    double? remaining;
    final rawRem = json['remaining_invoice_due'];
    if (rawRem is num) {
      remaining = rawRem.toDouble();
    } else if (rawRem != null) {
      remaining = double.tryParse(rawRem.toString());
    }
    return BillingOffsetProposalRespondResult(
      ok: json['ok'] == true,
      action: json['action']?.toString() ?? '',
      proposalId: json['proposal_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      appliedAmount: applied,
      paymentStatus: json['payment_status']?.toString(),
      remainingInvoiceDue: remaining,
      dispositionRequestId: json['disposition_request_id']?.toString(),
    );
  }
}

/// Plán pro vytvoření návrhu – settlement + částky před INSERTem.
class BillingOffsetProposalDraft {
  const BillingOffsetProposalDraft({
    required this.ownerProfileId,
    required this.settlementId,
    required this.proposedAmount,
    required this.remainingDue,
    required this.availableBalance,
    required this.currency,
  });

  final String ownerProfileId;
  final String settlementId;
  final double proposedAmount;
  final double remainingDue;
  final double availableBalance;
  final String currency;

  double get balanceAfterProposal =>
      (availableBalance - proposedAmount).clamp(0.0, double.infinity);
}
