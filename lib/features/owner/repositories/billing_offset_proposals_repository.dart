import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/models/billing_snapshot_offset_proposal.dart';
import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';
import 'package:falconest/features/owner/repositories/reservation_cash_transit_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Výjimka s [l10nKey] pro chyby návrhu doplatku (`.tr()` v UI).
class BillingOffsetProposalException implements Exception {
  const BillingOffsetProposalException(this.l10nKey);
  final String l10nKey;
  @override
  String toString() => l10nKey;
}

/// Dočasná diagnostická výjimka z RPC – nese surovou PostgREST/PostgreSQL zprávu pro SnackBar.
class BillingOffsetProposalRpcException implements Exception {
  BillingOffsetProposalRpcException(this.source);
  final PostgrestException source;

  /// Sestaví čitelný text pro debug UI (message + details + code z PostgREST).
  String get diagnosticMessage =>
      BillingOffsetProposalsRepository.formatPostgrestDiagnostic(source);

  @override
  String toString() => diagnosticMessage;
}

/// CRUD a RPC pro tabulku `billing_snapshot_offset_proposals`.
class BillingOffsetProposalsRepository {
  const BillingOffsetProposalsRepository();

  static const _eps = 1e-9;

  /// Dočasně: sestaví diagnostický text z PostgREST chyby (PostgreSQL RAISE EXCEPTION).
  ///
  /// PROČ: Generický SnackBar maskuje skutečný důvod selhání RPC (např.
  /// `BILLING_OFFSET_PROPOSAL:owner_mismatch`) – nutné pro ladění approval loopu.
  static String formatPostgrestDiagnostic(PostgrestException error) {
    final parts = <String>[];
    final message = error.message.trim();
    if (message.isNotEmpty) parts.add(message);

    final details = error.details?.toString().trim();
    if (details != null && details.isNotEmpty && details != message) {
      parts.add(details);
    }

    final hint = error.hint?.trim();
    if (hint != null && hint.isNotEmpty) parts.add('hint: $hint');

    final code = error.code?.trim();
    if (code != null && code.isNotEmpty) parts.add('code: $code');

    if (parts.isEmpty) {
      return 'PostgrestException (prázdná message)';
    }
    return parts.join(' | ');
  }

  /// Dočasně: libovolná chyba z respondProposal → text pro SnackBar (RPC detail nebo fallback).
  static String diagnosticMessageFrom(Object error) {
    if (error is BillingOffsetProposalRpcException) {
      return error.diagnosticMessage;
    }
    if (error is PostgrestException) {
      return formatPostgrestDiagnostic(error);
    }
    if (error is BillingOffsetProposalException) {
      return error.l10nKey;
    }
    return error.toString();
  }

  /// Aktivní návrh (`pending_owner`) pro konkrétní fakturu – max. jeden díky partial unique indexu.
  static Future<BillingSnapshotOffsetProposal?> getPendingForSnapshot({
    required String tenantId,
    required String billingSnapshotId,
  }) async {
    final tid = tenantId.trim();
    final sid = billingSnapshotId.trim();
    if (tid.isEmpty || sid.isEmpty) return null;

    final safe = SupabaseService.safeFrom('billing_snapshot_offset_proposals', tid);
    final raw = await safe
        .select()
        .eq('billing_snapshot_id', sid)
        .eq('status', BillingSnapshotOffsetProposalStatus.pendingOwner)
        .maybeSingle();
    if (raw == null) return null;
    return BillingSnapshotOffsetProposal.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  /// Všechny čekající návrhy majitele (Owner portál – banner / seznam).
  static Future<List<BillingSnapshotOffsetProposal>> listPendingForOwner({
    required String tenantId,
    required String ownerProfileId,
  }) async {
    final tid = tenantId.trim();
    final oid = ownerProfileId.trim();
    if (tid.isEmpty || oid.isEmpty) return [];

    final safe = SupabaseService.safeFrom('billing_snapshot_offset_proposals', tid);
    final rows = await safe
        .select()
        .eq('owner_profile_id', oid)
        .eq('status', BillingSnapshotOffsetProposalStatus.pendingOwner)
        .order('created_at', ascending: false);
    final list = rows is List ? rows : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => BillingSnapshotOffsetProposal.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  /// Připraví draft návrhu – ověří pool, vybere settlement s dostatečnou dostupnou částkou.
  static Future<BillingOffsetProposalDraft> prepareDraftForBillingClient({
    required String tenantId,
    required String billingClientId,
    required double finalToInvoice,
    required double existingOffsetAmount,
    required String currencyCode,
  }) async {
    final remainingDue =
        (finalToInvoice - existingOffsetAmount).clamp(0.0, double.infinity);
    if (remainingDue <= _eps) {
      throw const BillingOffsetProposalException(
        'admin.finance.billing_offset_proposal_no_remaining_due',
      );
    }

    final ownerProfileId =
        await OwnerCashDispositionRepository.resolveOwnerProfileIdForBillingClient(
      tenantId: tenantId,
      billingClientId: billingClientId,
    );
    if (ownerProfileId == null) {
      throw const BillingOffsetProposalException(
        'admin.finance.billing_snapshot_offset_client_not_linked',
      );
    }

    final availableBalance =
        await ReservationCashTransitRepository.getAvailableBalanceForOwner(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
      currencyCode: currencyCode,
    );
    if (availableBalance < remainingDue - _eps) {
      throw const BillingOffsetProposalException(
        'admin.finance.billing_offset_proposal_no_pool',
      );
    }

    final settlementId = await _pickSettlementId(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
      requiredAmount: remainingDue,
      currencyCode: currencyCode,
    );
    if (settlementId == null) {
      throw const BillingOffsetProposalException(
        'admin.finance.billing_offset_proposal_no_settlement',
      );
    }

    return BillingOffsetProposalDraft(
      ownerProfileId: ownerProfileId,
      settlementId: settlementId,
      proposedAmount: remainingDue,
      remainingDue: remainingDue,
      availableBalance: availableBalance,
      currency: currencyCode,
    );
  }

  /// Vybere settlement s nejvyšší dostupnou částkou, která pokryje [requiredAmount].
  static Future<String?> _pickSettlementId({
    required String tenantId,
    required String ownerProfileId,
    required double requiredAmount,
    required String currencyCode,
  }) async {
    final settlements =
        await ReservationCashTransitRepository.listAvailableSettlementsForOwner(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
      currencyCode: currencyCode,
    );
    if (settlements.isEmpty) return null;

    settlements.sort((a, b) {
      final av = a.availableAmount ?? 0;
      final bv = b.availableAmount ?? 0;
      return bv.compareTo(av);
    });

    for (final s in settlements) {
      final avail = s.availableAmount ?? 0;
      if (avail >= requiredAmount - _eps) {
        return s.id;
      }
    }
    return null;
  }

  /// Admin vytvoří návrh – INSERT přes RLS (validace stavu faktury v DB).
  static Future<BillingSnapshotOffsetProposal> createProposal({
    required String tenantId,
    required String billingSnapshotId,
    required String ownerProfileId,
    required String settlementId,
    required double proposedAmount,
    required String currency,
    required String proposedByProfileId,
  }) async {
    final safe = SupabaseService.safeFrom('billing_snapshot_offset_proposals', tenantId);
    final payload = SupabaseService.safeInsertPayload(tenantId, {
      'billing_snapshot_id': billingSnapshotId,
      'owner_profile_id': ownerProfileId,
      'settlement_id': settlementId,
      'proposed_amount': proposedAmount,
      'currency': currency,
      'proposed_by_profile_id': proposedByProfileId,
      'status': BillingSnapshotOffsetProposalStatus.pendingOwner,
    });
    final inserted = await safe.insert(payload).select().single();
    AppLogger.debug(
      'BillingOffsetProposal: vytvořen návrh snapshot=$billingSnapshotId '
      'amount=$proposedAmount',
    );
    return BillingSnapshotOffsetProposal.fromJson(
      Map<String, dynamic>.from(inserted as Map),
    );
  }

  /// Admin zruší aktivní návrh (pending_owner → cancelled_by_admin).
  static Future<void> cancelProposal({
    required String tenantId,
    required String proposalId,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final safe = SupabaseService.safeFrom('billing_snapshot_offset_proposals', tenantId);
    await safe
        .update({
          'status': BillingSnapshotOffsetProposalStatus.cancelledByAdmin,
          'updated_at': nowIso,
        })
        .eq('id', proposalId)
        .eq('status', BillingSnapshotOffsetProposalStatus.pendingOwner);
  }

  /// Majitel schválí nebo zamítne návrh – atomická mutace v PostgreSQL.
  static Future<BillingOffsetProposalRespondResult> respondProposal({
    required String proposalId,
    required String action,
    String? ownerRejectionNote,
  }) async {
    final params = <String, dynamic>{
      'p_proposal_id': proposalId,
      'p_action': action,
    };
    final note = ownerRejectionNote?.trim();
    if (note != null && note.isNotEmpty) {
      params['p_owner_rejection_note'] = note;
    }

    try {
      final raw = await SupabaseService.client.rpc(
        'respond_billing_offset_proposal',
        params: params,
      );
      if (raw is! Map) {
        throw StateError('respond_billing_offset_proposal: neplatná odpověď $raw');
      }
      return BillingOffsetProposalRespondResult.fromJson(
        Map<String, dynamic>.from(raw),
      );
    } on PostgrestException catch (e, st) {
      AppLogger.error(
        'respond_billing_offset_proposal RPC selhalo '
        '(proposalId=$proposalId, action=$action): ${formatPostgrestDiagnostic(e)}',
        e,
        st,
      );
      throw BillingOffsetProposalRpcException(e);
    }
  }
}
