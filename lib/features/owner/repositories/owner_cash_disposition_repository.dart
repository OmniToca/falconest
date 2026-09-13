import 'dart:math' as math;

import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/models/admin_owner_cash_disposition_row.dart';
import 'package:falconest/features/owner/models/owner_cash_disposition_request.dart';
import 'package:falconest/features/owner/models/owner_cash_transit_settlement.dart';
import 'package:falconest/features/owner/repositories/reservation_cash_transit_repository.dart';
import 'package:falconest/features/owner/services/owner_cash_offset_calculator.dart';
import 'package:flutter/foundation.dart';

/// Výjimka s [l10nKey] pro chyby zápočtu faktury (Admin `.tr()`).
class OwnerCashOffsetException implements Exception {
  const OwnerCashOffsetException(this.l10nKey);
  final String l10nKey;
  @override
  String toString() => l10nKey;
}

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
    // PROČ: Po schválení jiné žádosti může na tomto settlementu zbývat méně než plná `amount`.
    final availableOnSettlement =
        await ReservationCashTransitRepository.getAvailableAmountForSettlement(
      tenantId: tid,
      ownerProfileId: oid,
      settlementId: sid,
      currencyCode: match.currency,
    );
    if (amount > availableOnSettlement + 1e-9) {
      throw ArgumentError.value(
        amount,
        'amount',
        'nesmí přesáhnout dostupnou částku na tomto settlementu (po rezervacích z jiných žádostí)',
      );
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

  /// Přeloží `billing_snapshots.client_id` na `profiles.id` majitele (`clients.profile_id`).
  ///
  /// PROČ: Ve fakturaci je [BillingGroup.groupKey] = UUID klienta z tabulky `clients`, ale
  /// žádosti o dispozici ukládají `owner_profile_id` = profil přihlášeného majitele. Bez
  /// tohoto mapování `findInvoiceCreditRequestWithRemaining` vždy vrátí null (tiché selhání).
  static Future<String?> resolveOwnerProfileIdForBillingClient({
    required String tenantId,
    required String billingClientId,
  }) async {
    final tid = tenantId.trim();
    final cid = billingClientId.trim();
    if (tid.isEmpty || cid.isEmpty || cid == 'external') {
      AppLogger.debug(
        'OwnerCashOffset: resolveOwnerProfileId přeskočeno (tenant=$tid client=$cid)',
      );
      return null;
    }

    try {
      final safeClients = SupabaseService.safeFrom('clients', tid);
      final row = await safeClients
          .select('id, profile_id')
          .eq('id', cid)
          .maybeSingle();
      if (row != null) {
        final map = Map<String, dynamic>.from(row as Map);
        final profileId = map['profile_id']?.toString().trim();
        if (profileId != null && profileId.isNotEmpty) {
          AppLogger.debug(
            'OwnerCashOffset: clients.id=$cid → profile_id=$profileId',
          );
          return profileId;
        }
        AppLogger.debug(
          'OwnerCashOffset: clients.id=$cid nemá vyplněné profile_id (nelze najít žádost)',
        );
        return null;
      }

      // Záloha: groupKey už může být přímo profiles.id (starší data / ruční vazba).
      final safeProfiles = SupabaseService.safeFrom('profiles', tid);
      final prof = await safeProfiles.select('id').eq('id', cid).maybeSingle();
      if (prof != null) {
        AppLogger.debug(
          'OwnerCashOffset: groupKey=$cid odpovídá přímo profiles.id (bez řádku clients)',
        );
        return cid;
      }
      AppLogger.debug(
        'OwnerCashOffset: groupKey=$cid není clients.id ani profiles.id v tenantovi $tid',
      );
      return null;
    } catch (e, st) {
      AppLogger.error('OwnerCashOffset: resolveOwnerProfileId selhalo', e, st);
      return null;
    }
  }

  /// Najde nejnovější schválenou žádost **invoice_credit** majitele s nevyčerpaným objemem.
  ///
  /// PROČ: Admin při „Zápočet hotovosti“ na faktuře musí navázat na konkrétní žádost
  /// a zvýšit `used_amount` (aby „Zbývá k čerpání“ kleslo).
  static Future<OwnerCashDispositionRequest?> findInvoiceCreditRequestWithRemaining({
    required String tenantId,
    required String ownerProfileId,
  }) async {
    final tid = tenantId.trim();
    final oid = ownerProfileId.trim();
    if (tid.isEmpty || oid.isEmpty) return null;

    final safe = SupabaseService.safeFrom('owner_cash_disposition_requests', tid);
    final rows = await safe
        .select()
        .eq('owner_profile_id', oid)
        .eq('disposition_type', OwnerCashDispositionTypeValues.invoiceCredit)
        .inFilter('status', [
          OwnerCashDispositionStatusValues.approved,
          OwnerCashDispositionStatusValues.partiallyCompleted,
        ])
        .order('created_at', ascending: false);

    const eps = 1e-9;
    final parsed = _parseRows(rows);
    AppLogger.debug(
      'OwnerCashOffset: findByProfile owner_profile_id=$oid '
      'invoice_credit řádků=${parsed.length}',
    );
    for (final raw in parsed) {
      final remaining = raw.amount - raw.usedAmount;
      if (remaining > eps) {
        AppLogger.debug(
          'OwnerCashOffset: vybrána žádost id=${raw.id} remaining=$remaining '
          '(amount=${raw.amount} used=${raw.usedAmount})',
        );
        return raw;
      }
    }
    AppLogger.debug(
      'OwnerCashOffset: žádná žádost s remaining>0 pro owner_profile_id=$oid',
    );
    return null;
  }

  /// Stejné jako [findInvoiceCreditRequestWithRemaining], ale vstup je `billing_snapshots.client_id`.
  static Future<OwnerCashDispositionRequest?> findInvoiceCreditRequestForBillingClient({
    required String tenantId,
    required String billingClientId,
  }) async {
    final profileId = await resolveOwnerProfileIdForBillingClient(
      tenantId: tenantId,
      billingClientId: billingClientId,
    );
    if (profileId == null) return null;
    return findInvoiceCreditRequestWithRemaining(
      tenantId: tenantId,
      ownerProfileId: profileId,
    );
  }

  /// Sestaví plán zápočtu pro fakturu klienta – sdílený náhled Admin dialogu a [applyOffsetToSnapshot].
  static Future<OwnerCashOffsetPlan?> buildOffsetPlanForBillingClient({
    required String tenantId,
    required String billingClientId,
    required double invoiceDue,
    double existingOffsetAmount = 0,
    String currencyCode = 'EUR',
  }) async {
    final profileId = await resolveOwnerProfileIdForBillingClient(
      tenantId: tenantId,
      billingClientId: billingClientId,
    );
    if (profileId == null) return null;

    final request = await findInvoiceCreditRequestForBillingClient(
      tenantId: tenantId,
      billingClientId: billingClientId,
    );
    if (request == null) return null;

    final pool = await ReservationCashTransitRepository.getOwnerSettlementPool(
      tenantId: tenantId,
      ownerProfileId: profileId,
      currencyCode: currencyCode,
    );
    final requestRemaining = math.max(0.0, request.amount - request.usedAmount);

    return OwnerCashOffsetCalculator.compute(
      invoiceDue: invoiceDue,
      ownerPool: pool,
      requestRemaining: requestRemaining,
      existingOffsetAmount: existingOffsetAmount,
    );
  }

  /// Aplikuje částku z žádosti o dispozici (typ **invoice_credit**) na zmražené vyúčtování – zvýší [used_amount],
  /// vloží záporný řádek do [owner_cash_transit_settlements] (účetní protipohyb), nastaví snapshot.
  ///
  /// PROČ: Částečné umoření bez „černé díry“ v číslech; pool majitele = součet settlementů, proto musí
  /// zápočet faktury snížit pool zápornou částkou, ne jen `used_amount` u žádosti.
  /// Stav `cash_offset` / `partially_paid` a částka se odvozují z [OwnerCashOffsetCalculator] – volající je neposílá.
  static Future<OwnerCashOffsetPlan> applyOffsetToSnapshot({
    required String tenantId,
    required String snapshotId,
    required String requestId,
    required double invoiceDue,
    /// Profil dispečera (`profiles.id`) – sloupec `created_by` u protipohybu.
    required String adminProfileId,
    String currencyCode = 'EUR',
  }) async {
    final tid = tenantId.trim();
    final sid = snapshotId.trim();
    final rid = requestId.trim();
    if (tid.isEmpty || sid.isEmpty || rid.isEmpty) {
      throw ArgumentError('tenantId, snapshotId a requestId nesmí být prázdné');
    }
    if (invoiceDue <= 0) {
      throw ArgumentError.value(invoiceDue, 'invoiceDue', 'musí být kladné');
    }
    final adminPid = adminProfileId.trim();
    if (adminPid.isEmpty) {
      throw ArgumentError('adminProfileId nesmí být prázdné');
    }

    AppLogger.debug(
      'OwnerCashOffset: applyOffsetToSnapshot start snapshot=$sid request=$rid '
      'invoiceDue=$invoiceDue tenant=$tid',
    );

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
      final rawSnap = await safeSnap
          .select(
            'id, payment_status, offset_amount, offset_request_id',
          )
          .eq('id', sid)
          .maybeSingle();
      if (rawSnap == null) {
        throw StateError('Billing snapshot nenalezen nebo není v tenantovi');
      }
      final snapMap = Map<String, dynamic>.from(rawSnap);
      final existingPay =
          (snapMap['payment_status'] as String?)?.trim().toLowerCase() ?? '';
      final existingOffset = _readOffsetAmount(snapMap['offset_amount']);
      const eps = 1e-9;
      final invoiceRemaining = math.max(0.0, invoiceDue - existingOffset);

      // PROČ: Doplňkový zápočet povolen u partially_paid, dokud offset_amount < faktura.
      // Blokujeme plně uhrazené (paid / cash_offset) nebo když už není co strhnout.
      if (existingPay == 'paid') {
        throw const OwnerCashOffsetException(
          'admin.finance.billing_snapshot_offset_already_settled',
        );
      }
      if (existingPay == BillingSnapshotOffsetPaymentStatusValues.cashOffset ||
          invoiceRemaining <= eps) {
        throw const OwnerCashOffsetException(
          'admin.finance.billing_snapshot_offset_already_settled',
        );
      }

      final pool = await ReservationCashTransitRepository.getOwnerSettlementPool(
        tenantId: tid,
        ownerProfileId: request.ownerProfileId,
        currencyCode: currencyCode,
      );
      final requestRemaining = math.max(0.0, request.amount - request.usedAmount);
      final plan = OwnerCashOffsetCalculator.compute(
        invoiceDue: invoiceDue,
        ownerPool: pool,
        requestRemaining: requestRemaining,
        existingOffsetAmount: existingOffset,
      );

      if (plan.blocked || plan.amountToApply <= eps) {
        throw OwnerCashOffsetException(
          plan.blockReasonL10nKey ??
              'admin.finance.billing_snapshot_offset_insufficient_pool',
        );
      }

      final amountToApply = plan.amountToApply;
      final newSnapshotPaymentStatus = plan.derivedPaymentStatus;

      AppLogger.debug(
        'OwnerCashOffset: plán amountToApply=$amountToApply status=$newSnapshotPaymentStatus '
        'pool=$pool requestRem=$requestRemaining',
      );

      final safeSettlements = SupabaseService.safeFrom(
        'owner_cash_transit_settlements',
        tid,
      );
      final rawSourceSettlement = await safeSettlements
          .select()
          .eq('id', request.settlementId)
          .maybeSingle();
      if (rawSourceSettlement == null) {
        throw StateError(
          'Zdrojový settlement žádosti nenalezen (settlement_id=${request.settlementId})',
        );
      }
      final sourceMap = Map<String, dynamic>.from(rawSourceSettlement as Map);
      final sourceCurrency =
          (sourceMap['currency'] as String?)?.trim().toUpperCase() ?? 'EUR';
      final sourceReservationId =
          sourceMap['reservation_id']?.toString().trim();
      final sourceApartmentId = sourceMap['apartment_id']?.toString().trim();
      final sourceTaskId = sourceMap['task_id']?.toString().trim();

      if (pool < amountToApply - eps) {
        throw const OwnerCashOffsetException(
          'admin.finance.billing_snapshot_offset_insufficient_pool',
        );
      }

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

      // Účetní protipohyb: Reálné stržení peněz z hotovostního poolu majitele za uhrazenou fakturu.
      final offsetNote =
          'Zápočet podkladu $sid proti žádosti $rid';
      final offsetPayload = <String, dynamic>{
        'amount': -amountToApply,
        'currency': sourceCurrency.isEmpty ? 'EUR' : sourceCurrency,
        'created_by': adminPid,
        'note': offsetNote,
        if (sourceReservationId != null && sourceReservationId.isNotEmpty)
          'reservation_id': sourceReservationId,
        if (sourceApartmentId != null && sourceApartmentId.isNotEmpty)
          'apartment_id': sourceApartmentId,
        if (sourceTaskId != null && sourceTaskId.isNotEmpty) 'task_id': sourceTaskId,
      };
      // Rozšířené instance DB mají sloupec status – označíme vyrovnaný zápočet.
      if (sourceMap.containsKey('status')) {
        offsetPayload['status'] = 'settled';
      }
      final offsetInsert = await safeSettlements
          .insert(SupabaseService.safeInsertPayload(tid, offsetPayload))
          .select('id')
          .maybeSingle();
      String? offsetSettlementId;
      if (offsetInsert != null) {
        offsetSettlementId =
            Map<String, dynamic>.from(offsetInsert as Map)['id']?.toString();
      }

      AppLogger.debug(
        'OwnerCashOffset: vložen protipohyb settlement id=$offsetSettlementId '
        'amount=${-amountToApply} $sourceCurrency',
      );

      await safeSnap.update({
        'payment_status': newSnapshotPaymentStatus,
        'paid_at': nowIso,
        'offset_amount': existingOffset + amountToApply,
        'offset_request_id': rid,
        'offset_applied_at': nowIso,
      }).eq('id', sid);

      AppLogger.debug(
        'OwnerCashOffset: applyOffsetToSnapshot OK used_amount=$newUsed '
        'requestStatus=$newRequestStatus snapshot=$sid '
        'offsetTotal=${existingOffset + amountToApply} (+$amountToApply)',
      );

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
            'offset_settlement_id': offsetSettlementId,
            'offset_settlement_amount': -amountToApply,
            'used_amount_after': newUsed,
            'request_amount': request.amount,
            'request_status_after': newRequestStatus,
            'snapshot_payment_status': newSnapshotPaymentStatus,
            'snapshot_offset_amount': existingOffset + amountToApply,
            'snapshot_offset_amount_this_tranche': amountToApply,
            'invoice_remaining_after': plan.remainingInvoiceDue,
          },
        );
      } catch (auditErr, auditSt) {
        debugPrint('ERROR: AuditLogService po DISPOSITION_OFFSET_APPLIED: $auditErr');
        debugPrint('ERROR: $auditSt');
      }

      return plan;
    } catch (e, st) {
      AppLogger.error('OwnerCashOffset: applyOffsetToSnapshot selhalo', e, st);
      rethrow;
    }
  }

  static double _readOffsetAmount(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }
}
