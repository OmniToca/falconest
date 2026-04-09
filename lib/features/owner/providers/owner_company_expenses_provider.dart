import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Jedna firemní výdajová transakce (COMPANY_EXPENSE) navázaná na byt majitele.
///
/// PROČ: Majitel vidí jen řádky s [apartmentId] ve svém vlastnictví; schvalování
/// zapisujeme do [metadata] (bez nových tabulek).
class OwnerCompanyExpenseRow {
  const OwnerCompanyExpenseRow({
    required this.id,
    required this.amount,
    required this.apartmentId,
    this.note,
    this.createdAt,
    this.metadata = const {},
  });

  final String id;
  final double amount;
  final String apartmentId;
  final String? note;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  bool get ownerApproved => metadata['owner_approved'] == true;

  DateTime? get ownerApprovedAt {
    final raw = metadata['owner_approved_at'];
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }
}

/// Načte COMPANY_EXPENSE transakce pro vlastněné apartmány.
final ownerCompanyExpensesProvider =
    FutureProvider<List<OwnerCompanyExpenseRow>>((ref) async {
  final apartments = await ref.watch(ownerApartmentsProvider.future);
  final ownedIds = apartments
      .map((a) => a.id)
      .where((id) => id.isNotEmpty)
      .toList();
  if (ownedIds.isEmpty) return [];

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  try {
    final res = await SupabaseService.safeFrom(
      'employee_cash_transactions',
      tenantId,
    )
        .select(
          'id, amount, note, created_at, apartment_id, metadata',
        )
        .eq('transaction_type', 'COMPANY_EXPENSE')
        .inFilter('apartment_id', ownedIds)
        .order('created_at', ascending: false);

    final list = res as List? ?? [];
    final out = <OwnerCompanyExpenseRow>[];
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = (m['id']?.toString() ?? '').trim();
      if (id.isEmpty) continue;
      final apt = (m['apartment_id']?.toString() ?? '').trim();
      if (apt.isEmpty) continue;
      final amountRaw = m['amount'];
      final amount = amountRaw is num
          ? amountRaw.toDouble()
          : (double.tryParse(amountRaw?.toString() ?? '') ?? 0.0);
      DateTime? createdAt;
      final ca = m['created_at'];
      if (ca is String) createdAt = DateTime.tryParse(ca)?.toLocal();
      if (ca is DateTime) createdAt = ca.toLocal();
      Map<String, dynamic> meta = {};
      final rawMeta = m['metadata'];
      if (rawMeta is Map) {
        meta = Map<String, dynamic>.from(rawMeta);
      }
      out.add(
        OwnerCompanyExpenseRow(
          id: id,
          amount: amount,
          apartmentId: apt,
          note: (m['note'] as String?)?.trim().isEmpty == true
              ? null
              : (m['note'] as String?)?.trim(),
          createdAt: createdAt,
          metadata: meta,
        ),
      );
    }
    return out;
  } catch (e, st) {
    AppLogger.error('ownerCompanyExpensesProvider: načtení COMPANY_EXPENSE selhalo', e, st);
    return [];
  }
});

/// Zapíše schválení majitele do [metadata] transakce (merge nad existujícím JSON).
Future<void> ownerApproveCompanyExpense({
  required String tenantId,
  required String transactionId,
  required Map<String, dynamic> currentMetadata,
}) async {
  final merged = Map<String, dynamic>.from(currentMetadata);
  merged['owner_approved'] = true;
  merged['owner_approved_at'] = DateTime.now().toUtc().toIso8601String();
  await SupabaseService.safeFrom('employee_cash_transactions', tenantId)
      .update({'metadata': merged})
      .eq('id', transactionId.trim());
}
