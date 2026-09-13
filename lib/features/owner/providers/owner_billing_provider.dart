import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/owner_view_impersonation_providers.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Model pro jeden záznam z tabulky billing_snapshots.
///
/// Odpovídá struktuře DB sloupců. [snapshotData] obsahuje zmražené
/// vyúčtování: client_name, currency, total_to_invoice, total_expenses,
/// final_to_invoice a pole items (úkoly s cenami).
class BillingSnapshotModel {
  const BillingSnapshotModel({
    required this.id,
    required this.tenantId,
    required this.clientId,
    required this.billingPeriod,
    required this.snapshotData,
    required this.lockedAt,
    this.lockedBy,
    this.paymentStatus = 'unpaid',
    this.paidAt,
    this.invoicePdfUrl,
    this.offsetAmount = 0,
    this.offsetRequestId,
    this.offsetAppliedAt,
  });

  final String id;
  final String tenantId;
  final String clientId;
  final DateTime billingPeriod;
  final Map<String, dynamic> snapshotData;
  final DateTime lockedAt;
  final String? lockedBy;

  /// `unpaid` | `paid` | `cash_offset` (CHECK v DB, migrace `20260410000000`).
  final String paymentStatus;
  final DateTime? paidAt;
  final String? invoicePdfUrl;
  final double offsetAmount;
  final String? offsetRequestId;
  final DateTime? offsetAppliedAt;

  factory BillingSnapshotModel.fromJson(Map<String, dynamic> json) {
    final periodRaw = json['billing_period'];
    DateTime period;
    if (periodRaw is DateTime) {
      period = periodRaw;
    } else if (periodRaw is String) {
      period = DateTime.tryParse(periodRaw) ?? DateTime.now();
    } else {
      period = DateTime.now();
    }
    final lockedRaw = json['locked_at'];
    DateTime locked;
    if (lockedRaw is DateTime) {
      locked = lockedRaw;
    } else if (lockedRaw is String) {
      locked = DateTime.tryParse(lockedRaw) ?? DateTime.now();
    } else {
      locked = DateTime.now();
    }
    final data = json['snapshot_data'];
    final payRaw = json['payment_status']?.toString().trim();
    final paymentStatus = (payRaw != null && payRaw.isNotEmpty)
        ? payRaw
        : 'unpaid';
    final paidRaw = json['paid_at'];
    DateTime? paidAt;
    if (paidRaw is DateTime) {
      paidAt = paidRaw;
    } else if (paidRaw is String) {
      paidAt = DateTime.tryParse(paidRaw);
    }
    final offsetRaw = json['offset_amount'];
    double offsetAmount = 0;
    if (offsetRaw is num) {
      offsetAmount = offsetRaw.toDouble();
    } else if (offsetRaw != null) {
      offsetAmount = double.tryParse(offsetRaw.toString()) ?? 0;
    }
    final offsetReqId = (json['offset_request_id'] as String?)?.trim();
    final offsetAtRaw = json['offset_applied_at'];
    DateTime? offsetAppliedAt;
    if (offsetAtRaw is DateTime) {
      offsetAppliedAt = offsetAtRaw;
    } else if (offsetAtRaw is String) {
      offsetAppliedAt = DateTime.tryParse(offsetAtRaw);
    }
    return BillingSnapshotModel(
      id: (json['id'] as String?)?.trim() ?? '',
      tenantId: (json['tenant_id'] as String?)?.trim() ?? '',
      clientId: (json['client_id'] as String?)?.trim() ?? '',
      billingPeriod: period,
      snapshotData: data is Map<String, dynamic> ? data : {},
      lockedAt: locked,
      lockedBy: (json['locked_by'] as String?)?.trim(),
      paymentStatus: paymentStatus,
      paidAt: paidAt,
      invoicePdfUrl: (json['invoice_pdf_url'] as String?)?.trim(),
      offsetAmount: offsetAmount >= 0 ? offsetAmount : 0,
      offsetRequestId:
          offsetReqId != null && offsetReqId.isNotEmpty ? offsetReqId : null,
      offsetAppliedAt: offsetAppliedAt,
    );
  }
}

/// Načte zmražená vyúčtování pro přihlášeného majitele (Owner).
///
/// Majitel je propojen s klientem přes clients.profile_id. Získáme jeho
/// client_id v rámci aktuálního tenant_id a stáhneme billing_snapshots
/// pro tyto klienty, seřazené podle billing_period sestupně.
///
/// PROČ: Kvůli [IndexedStack] v [OwnerLayout] zůstává záložka Fakturace vždy v subtree –
/// pro čerstvá data v investiční výsledovce se provider invaliduje při otevření
/// [OwnerInvestmentDashboard].
final ownerBillingSnapshotsProvider =
    FutureProvider<List<BillingSnapshotModel>>((ref) async {
  final profileId = ref.watch(effectiveProfileIdProvider);
  final tenantId = ref.watch(authNotifierProvider).state.tenantId;
  if (profileId == null || profileId.isEmpty || tenantId == null || tenantId.isEmpty) {
    return [];
  }

  // Krok 1: Získat client_id majitele (clients.profile_id = náš profil, tenant_id = naše agentura).
  final clientsRes = await SupabaseService.client
      .from('clients')
      .select('id')
      .eq('profile_id', profileId)
      .eq('tenant_id', tenantId)
      .isFilter('deleted_at', null);

  final clientsList = clientsRes as List;
  if (clientsList.isEmpty) return [];

  final clientIds = clientsList
      .map((e) => (e as Map)['id']?.toString())
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>()
      .toList();

  if (clientIds.isEmpty) return [];

  // Krok 2: Stáhnout billing_snapshots pro naše client_id, seřazeno sestupně.
  final snapshotsRes = await SupabaseService.client
      .from('billing_snapshots')
      .select(
        'id, tenant_id, client_id, billing_period, snapshot_data, locked_at, locked_by, payment_status, paid_at, invoice_pdf_url, offset_amount, offset_request_id, offset_applied_at',
      )
      .inFilter('client_id', clientIds)
      .order('billing_period', ascending: false);

  final snapshotsList = snapshotsRes as List;
  return snapshotsList
      .map((e) => BillingSnapshotModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
