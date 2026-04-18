import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/owner/models/admin_owner_cash_disposition_row.dart';
import 'package:falconest/features/owner/models/owner_cash_disposition_request.dart';
import 'package:falconest/features/owner/models/owner_cash_transit_settlement.dart';
import 'package:falconest/features/owner/repositories/reservation_cash_transit_repository.dart';
import 'package:flutter/foundation.dart';

/// Výjimka s [l10nKey] z `assets/translations` pro zobrazení v UI majitele (`.tr()`).
class OwnerDispositionValidationException implements Exception {
  const OwnerDispositionValidationException(this.l10nKey);
  final String l10nKey;
  @override
  String toString() => l10nKey;
}

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
  /// Část částky již vyčerpána (např. částečné umoření faktury).
  static const partiallyCompleted = 'partially_completed';
  /// Hotovost připravena k vyzvednutí v trezoru (nastavuje typicky agentura).
  static const readyForPickup = 'ready_for_pickup';
}

/// Povolené hodnoty [newSnapshotPaymentStatus] pro [OwnerCashDispositionRepository.applyOffsetToSnapshot].
abstract final class BillingSnapshotOffsetPaymentStatusValues {
  static const cashOffset = 'cash_offset';
  static const partiallyPaid = 'partially_paid';
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
    OwnerCashDispositionStatusValues.partiallyCompleted,
    OwnerCashDispositionStatusValues.readyForPickup,
  };

  /// Stavy žádosti, ve kterých majitel nesmí měnit [pickup_date] (viz [updateOwnerRequestPickupDate]).
  static const _ownerPickupEditBlockedStatuses = {
    OwnerCashDispositionStatusValues.approved,
    OwnerCashDispositionStatusValues.completed,
    OwnerCashDispositionStatusValues.readyForPickup,
    OwnerCashDispositionStatusValues.partiallyCompleted,
    OwnerCashDispositionStatusValues.rejected,
  };

  static const Duration _minPickupLeadTime = Duration(hours: 48);

  /// PROČ: Jednotná byznysová pravidla pro vault_pickup – minimální odstup od „teď“ (UTC).
  static void _assertPickupUtcAtLeast48HoursAhead(DateTime pickupUtc) {
    final minAllowed = DateTime.now().toUtc().add(_minPickupLeadTime);
    if (pickupUtc.isBefore(minAllowed)) {
      throw const OwnerDispositionValidationException(
        'owner.cash_disposition_validation_pickup_48h',
      );
    }
  }

  /// Validace polí podle typu dispozice při vytvoření žádosti.
  static void _validateCreateDispositionFields({
    required String dispositionType,
    String? iban,
    DateTime? pickupDate,
  }) {
    if (dispositionType == OwnerCashDispositionTypeValues.bankTransfer) {
      final ib = iban?.trim() ?? '';
      if (ib.isEmpty) {
        throw const OwnerDispositionValidationException(
          'owner.cash_disposition_validation_iban_required',
        );
      }
    }
    if (dispositionType == OwnerCashDispositionTypeValues.vaultPickup) {
      if (pickupDate == null) {
        throw const OwnerDispositionValidationException(
          'owner.cash_disposition_validation_pickup_required',
        );
      }
      _assertPickupUtcAtLeast48HoursAhead(pickupDate.toUtc());
    }
  }

  static final _allowedOffsetSnapshotPaymentStatuses = {
    BillingSnapshotOffsetPaymentStatusValues.cashOffset,
    BillingSnapshotOffsetPaymentStatusValues.partiallyPaid,
  };

  static List<OwnerCashDispositionRequest> _parseRows(dynamic rows) {
    final list = rows is List ? rows : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => OwnerCashDispositionRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Sloučí existující [admin_notes] s novým řádkem od dispečinku.
  ///
  /// PROČ: Majitel může při INSERTu zanechat text v `admin_notes` bez struktury – při prvním doplnění
  /// z admin UI se obalí jako `Owner: …`. Každá další poznámka agentury jde na nový řádek `Admin: …`
  /// a původní obsah (včetně zprávy majitele) se nepřepisuje.
  static String mergeAdminNotesAppend({
    required String? existingRaw,
    required String newAdminSegment,
  }) {
    final segment = newAdminSegment.trim();
    if (segment.isEmpty) return existingRaw?.trim() ?? '';
    final adminLine = 'Admin: $segment';
    final existing = existingRaw?.trim() ?? '';
    if (existing.isEmpty) return adminLine;
    if (existing.startsWith('Owner:')) {
      return '$existing\n$adminLine';
    }
    if (existing.contains('\nAdmin:')) {
      return '$existing\n$adminLine';
    }
    return 'Owner: $existing\n$adminLine';
  }

  static Map<String, dynamic>? _profileMapFromEmbed(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  static String _ownerDisplayNameFromProfile(Map<String, dynamic>? p) {
    if (p == null) return '';
    final name = p['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final fn = p['first_name']?.toString().trim() ?? '';
    final ln = p['last_name']?.toString().trim() ?? '';
    final combined = '$fn $ln'.trim();
    if (combined.isNotEmpty) return combined;
    final email = p['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return '';
  }

  static AdminOwnerCashDispositionRow _parseAdminTenantRow(Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);
    final profRaw = copy.remove('profiles');
    final prof = _profileMapFromEmbed(profRaw);
    final display = _ownerDisplayNameFromProfile(prof);
    final email = prof?['email']?.toString();
    return AdminOwnerCashDispositionRow(
      request: OwnerCashDispositionRequest.fromJson(copy),
      ownerDisplayName: display.isNotEmpty ? display : '—',
      ownerEmail: email != null && email.isNotEmpty ? email : null,
    );
  }

  /// Admin / manager: všechny žádosti tenanta s embedovaným profilem majitele (jméno, e-mail).
  static Future<List<AdminOwnerCashDispositionRow>> getRequestsForTenant({
    required String tenantId,
  }) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return [];

    const selectFields = '''
*,
profiles!owner_cash_disposition_requests_owner_profile_id_fkey (
  name,
  email,
  first_name,
  last_name
)
''';

    final safe = SupabaseService.safeFrom('owner_cash_disposition_requests', tid);
    final rows = await safe.select(selectFields).order('created_at', ascending: false);
    final list = rows is List ? rows : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => _parseAdminTenantRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Majitel vytvoří žádost; RLS ověří vazbu na settlement a byt.
  ///
  /// [noteForAgency]: volitelný text z klientského portálu. Ukládá se do sloupce
  /// `admin_notes` již při INSERTu (agentura ho vidí jako zprávu od majitele;
  /// později ho může doplnit při zpracování žádosti).
  static Future<OwnerCashDispositionRequest> createRequest({
    required String tenantId,
    required String ownerProfileId,
    required String settlementId,
    required String dispositionType,
    required double amount,
    String? noteForAgency,
    /// Povinné u [OwnerCashDispositionTypeValues.bankTransfer] (validace non-empty).
    String? iban,
    /// Povinné u [OwnerCashDispositionTypeValues.vaultPickup]; min. 48 h od nynějška (UTC).
    DateTime? pickupDate,
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

    _validateCreateDispositionFields(
      dispositionType: dispositionType,
      iban: iban,
      pickupDate: pickupDate,
    );

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
    final note = noteForAgency?.trim();
    final ibanTrim = iban?.trim();
    final pickupUtc = pickupDate?.toUtc();
    final payload = SupabaseService.safeInsertPayload(tid, {
      'settlement_id': sid,
      'owner_profile_id': oid,
      'disposition_type': dispositionType,
      'amount': amount,
      'status': OwnerCashDispositionStatusValues.pending,
      if (note != null && note.isNotEmpty) 'admin_notes': note,
      if (ibanTrim != null && ibanTrim.isNotEmpty) 'iban': ibanTrim,
      if (dispositionType == OwnerCashDispositionTypeValues.vaultPickup &&
          pickupUtc != null)
        'pickup_date': pickupUtc.toIso8601String(),
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

  /// Majitel změní [pickup_date] u žádosti typu vault (jen **pending**; RLS + byznys).
  ///
  /// PROČ: Po schválení / přípravě k vyzvednutí / dokončení už nesmí majitel termín měnit.
  static Future<OwnerCashDispositionRequest> updateOwnerRequestPickupDate({
    required String tenantId,
    required String ownerProfileId,
    required String requestId,
    required DateTime newPickupDate,
  }) async {
    final tid = tenantId.trim();
    final oid = ownerProfileId.trim();
    final rid = requestId.trim();
    if (tid.isEmpty || oid.isEmpty || rid.isEmpty) {
      throw ArgumentError('tenantId, ownerProfileId a requestId nesmí být prázdné');
    }

    _assertPickupUtcAtLeast48HoursAhead(newPickupDate.toUtc());

    final safe = SupabaseService.safeFrom('owner_cash_disposition_requests', tid);
    final raw = await safe.select().eq('id', rid).eq('owner_profile_id', oid).maybeSingle();
    if (raw == null) {
      throw StateError('Žádost nenalezena nebo k ní nemáte přístup');
    }
    final existing = OwnerCashDispositionRequest.fromJson(
      Map<String, dynamic>.from(raw),
    );
    if (existing.tenantId != tid) {
      throw StateError('Neshoda tenant_id u žádosti');
    }
    if (existing.dispositionType != OwnerCashDispositionTypeValues.vaultPickup) {
      throw const OwnerDispositionValidationException(
        'owner.cash_disposition_validation_pickup_only_vault',
      );
    }
    if (_ownerPickupEditBlockedStatuses.contains(existing.status)) {
      throw const OwnerDispositionValidationException(
        'owner.cash_disposition_validation_pickup_locked',
      );
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final updated = await safe
        .update({
          'pickup_date': newPickupDate.toUtc().toIso8601String(),
          'updated_at': nowIso,
        })
        .eq('id', rid)
        .eq('owner_profile_id', oid)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw StateError('Aktualizaci pickup_date se nepodařilo provést (RLS nebo stav žádosti)');
    }
    return OwnerCashDispositionRequest.fromJson(
      Map<String, dynamic>.from(updated),
    );
  }

  /// Admin / manager mění stav žádosti; volitelně **připojí** nový řádek do [admin_notes] (viz [mergeAdminNotesAppend]).
  ///
  /// [appendAdminNote]: jen text přidaný v tomto kroku; prázdný = sloupec `admin_notes` se nemění.
  static Future<void> updateRequestStatus({
    required String tenantId,
    required String requestId,
    required String status,
    String? appendAdminNote,
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
    };

    final note = appendAdminNote?.trim();
    if (note != null && note.isNotEmpty) {
      final existingRow = await safe.select('admin_notes').eq('id', rid).maybeSingle();
      String? existingNotes;
      if (existingRow != null) {
        existingNotes =
            Map<String, dynamic>.from(existingRow as Map)['admin_notes']?.toString();
      }
      payload['admin_notes'] = mergeAdminNotesAppend(
        existingRaw: existingNotes,
        newAdminSegment: note,
      );
    }

    await safe.update(payload).eq('id', rid);
  }

  /// Aplikuje částku z žádosti o dispozici (typ **invoice_credit**) na zmražené vyúčtování – zvýší [used_amount],
  /// případně uzavře žádost, a nastaví [billing_snapshots.payment_status] + [paid_at].
  ///
  /// PROČ: Částečné umoření bez „černé díry“ v číslech; celá akce podléhá RLS (UPDATE žádosti + snapshotu).
  /// [newSnapshotPaymentStatus] musí být `cash_offset` (plný zápočet) nebo `partially_paid` (část faktury).
  static Future<void> applyOffsetToSnapshot({
    required String tenantId,
    required String snapshotId,
    required String requestId,
    required double amountToApply,
    required String newSnapshotPaymentStatus,
  }) async {
    final tid = tenantId.trim();
    final sid = snapshotId.trim();
    final rid = requestId.trim();
    if (tid.isEmpty || sid.isEmpty || rid.isEmpty) {
      throw ArgumentError('tenantId, snapshotId a requestId nesmí být prázdné');
    }
    if (amountToApply <= 0) {
      throw ArgumentError.value(amountToApply, 'amountToApply', 'musí být kladné');
    }
    if (!_allowedOffsetSnapshotPaymentStatuses.contains(newSnapshotPaymentStatus)) {
      throw ArgumentError.value(
        newSnapshotPaymentStatus,
        'newSnapshotPaymentStatus',
        'povoleno jen cash_offset nebo partially_paid',
      );
    }

    try {
      final safeReq = SupabaseService.safeFrom('owner_cash_disposition_requests', tid);
      final rawReq = await safeReq.select().eq('id', rid).maybeSingle();
      if (rawReq == null) {
        throw StateError('Žádost o dispozici nenalezena nebo není v tenantovi');
      }
      final request = OwnerCashDispositionRequest.fromJson(
        Map<String, dynamic>.from(rawReq),
      );
      if (request.tenantId != tid) {
        throw StateError('Neshoda tenant_id u žádosti');
      }
      if (request.dispositionType != OwnerCashDispositionTypeValues.invoiceCredit) {
        throw StateError(
          'applyOffsetToSnapshot: podporován je jen typ invoice_credit',
        );
      }
      if (request.status != OwnerCashDispositionStatusValues.approved &&
          request.status != OwnerCashDispositionStatusValues.partiallyCompleted) {
        throw StateError(
          'Žádost musí být ve stavu approved nebo partially_completed',
        );
      }

      final safeSnap = SupabaseService.safeFrom('billing_snapshots', tid);
      final rawSnap = await safeSnap.select('id').eq('id', sid).maybeSingle();
      if (rawSnap == null) {
        throw StateError('Billing snapshot nenalezen nebo není v tenantovi');
      }

      const eps = 1e-9;
      final newUsed = request.usedAmount + amountToApply;
      if (newUsed > request.amount + eps) {
        throw ArgumentError(
          'Částka překračuje zbývající objem žádosti '
          '(used ${request.usedAmount} + $amountToApply > ${request.amount})',
        );
      }

      final newRequestStatus =
          (newUsed >= request.amount - eps)
          ? OwnerCashDispositionStatusValues.completed
          : OwnerCashDispositionStatusValues.partiallyCompleted;

      final nowIso = DateTime.now().toUtc().toIso8601String();

      await safeReq.update({
        'used_amount': newUsed,
        'status': newRequestStatus,
        'updated_at': nowIso,
      }).eq('id', rid);

      await safeSnap.update({
        'payment_status': newSnapshotPaymentStatus,
        'paid_at': nowIso,
      }).eq('id', sid);

      try {
        await AuditLogService.log(
          tenantId: tid,
          userId: SupabaseService.client.auth.currentUser?.id,
          actionType: 'DISPOSITION_OFFSET_APPLIED',
          tableName: 'owner_cash_disposition_requests',
          recordId: rid,
          details: {
            'snapshot_id': sid,
            'request_id': rid,
            'amount_applied': amountToApply,
            'used_amount_after': newUsed,
            'request_amount': request.amount,
            'request_status_after': newRequestStatus,
            'snapshot_payment_status': newSnapshotPaymentStatus,
          },
        );
      } catch (auditErr, auditSt) {
        debugPrint('ERROR: AuditLogService po DISPOSITION_OFFSET_APPLIED: $auditErr');
        debugPrint('ERROR: $auditSt');
      }
    } catch (e, st) {
      debugPrint('ERROR: applyOffsetToSnapshot: $e');
      debugPrint('ERROR: $st');
      rethrow;
    }
  }
}
