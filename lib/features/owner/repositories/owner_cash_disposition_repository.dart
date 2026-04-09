import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/owner/models/owner_cash_disposition_request.dart';
import 'package:falconest/features/owner/models/owner_cash_transit_settlement.dart';
import 'package:falconest/features/owner/repositories/reservation_cash_transit_repository.dart';

/// Konstanty odpovídající CHECK constraintům v migraci `20260409143000_owner_cash_dispositions.sql`.
abstract final class OwnerCashDispositionTypeValues {
  static const bankTransfer = 'bank_transfer';
  static const invoiceCredit = 'invoice_credit';
  static const vaultPickup = 'vault_pickup';
}

/// Konstanty sloupce `status` u žádostí o dispozici.
abstract final class OwnerCashDispositionStatusValues {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const completed = 'completed';
}

/// CRUD logika pro `owner_cash_disposition_requests` (Owner INSERT, Admin UPDATE, oba SELECT přes RLS).
class OwnerCashDispositionRepository {
  OwnerCashDispositionRepository._();

  static final _allowedTypes = {
    OwnerCashDispositionTypeValues.bankTransfer,
    OwnerCashDispositionTypeValues.invoiceCredit,
    OwnerCashDispositionTypeValues.vaultPickup,
  };

  static final _allowedStatuses = {
    OwnerCashDispositionStatusValues.pending,
    OwnerCashDispositionStatusValues.approved,
    OwnerCashDispositionStatusValues.rejected,
    OwnerCashDispositionStatusValues.completed,
  };

  static List<OwnerCashDispositionRequest> _parseRows(dynamic rows) {
    final list = rows is List ? rows : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => OwnerCashDispositionRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Majitel vytvoří žádost; RLS ověří vazbu na settlement a byt.
  static Future<OwnerCashDispositionRequest> createRequest({
    required String tenantId,
    required String ownerProfileId,
    required String settlementId,
    required String dispositionType,
    required double amount,
  }) async {
    final tid = tenantId.trim();
    final oid = ownerProfileId.trim();
    final sid = settlementId.trim();
    if (tid.isEmpty || oid.isEmpty || sid.isEmpty) {
      throw ArgumentError('tenantId, ownerProfileId a settlementId nesmí být prázdné');
    }
    if (!_allowedTypes.contains(dispositionType)) {
      throw ArgumentError.value(dispositionType, 'dispositionType', 'neplatný typ dispozice');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'musí být kladné');
    }

    final settlements = await ReservationCashTransitRepository.listSettlementsForOwnerProfile(
      tenantId: tid,
      ownerProfileId: oid,
    );
    OwnerCashTransitSettlement? match;
    for (final s in settlements) {
      if (s.id == sid) {
        match = s;
        break;
      }
    }
    if (match == null) {
      throw StateError('Settlement není v portfoliu majitele nebo neexistuje');
    }
    if (amount > match.amount + 1e-9) {
      throw ArgumentError.value(amount, 'amount', 'nesmí přesáhnout uznanou částku settlementu');
    }

    final safe = SupabaseService.safeFrom('owner_cash_disposition_requests', tid);
    final payload = SupabaseService.safeInsertPayload(tid, {
      'settlement_id': sid,
      'owner_profile_id': oid,
      'disposition_type': dispositionType,
      'amount': amount,
      'status': OwnerCashDispositionStatusValues.pending,
    });

    final inserted = await safe.insert(payload).select().single();
    return OwnerCashDispositionRequest.fromJson(Map<String, dynamic>.from(inserted));
  }

  /// Seznam žádostí majitele (nejnovější první).
  static Future<List<OwnerCashDispositionRequest>> getRequestsForOwner({
    required String tenantId,
    required String ownerProfileId,
  }) async {
    final tid = tenantId.trim();
    final oid = ownerProfileId.trim();
    if (tid.isEmpty || oid.isEmpty) return [];

    final safe = SupabaseService.safeFrom('owner_cash_disposition_requests', tid);
    final rows = await safe
        .select()
        .eq('owner_profile_id', oid)
        .order('created_at', ascending: false);
    return _parseRows(rows);
  }

  /// Admin / manager mění stav žádosti (a volitelně interní poznámku).
  static Future<void> updateRequestStatus({
    required String tenantId,
    required String requestId,
    required String status,
    String? adminNotes,
  }) async {
    final tid = tenantId.trim();
    final rid = requestId.trim();
    if (tid.isEmpty || rid.isEmpty) {
      throw ArgumentError('tenantId a requestId nesmí být prázdné');
    }
    if (!_allowedStatuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'neplatný stav');
    }

    final safe = SupabaseService.safeFrom('owner_cash_disposition_requests', tid);
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'admin_notes':? adminNotes,
    };
    await safe.update(payload).eq('id', rid);
  }
}
