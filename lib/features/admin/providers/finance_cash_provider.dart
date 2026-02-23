import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Načte seznam peněženek zaměstnanců (Zaměstnanecká pokladna) pro aktuální tenanta.
final employeeCashWalletsProvider = FutureProvider<List<EmployeeCashWalletRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  return CashWalletRepository.instance.fetchWalletsForTenant(tenantId);
});

/// Řádek úkolu s nevybranou hotovostí – pro sekci alertů v Zaměstnanecké pokladně.
class FailedCashCollectionRow {
  const FailedCashCollectionRow({
    required this.taskId,
    required this.taskTitle,
    required this.workerName,
    required this.completedAt,
    required this.amountToCollect,
  });
  final String taskId;
  final String taskTitle;
  final String workerName;
  final DateTime? completedAt;
  final double amountToCollect;
}

/// Sekce kritických alertů: Zobrazuje úkoly, kde pracovník v terénu nepotvrdil výběr hotovosti.
/// Načte completed úkoly s metadata.cash_collection_failed == true (bez cash_collection_resolved).
final failedCashCollectionsProvider =
    FutureProvider<List<FailedCashCollectionRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  try {
    final res = await SupabaseService.client
        .from('tasks')
        .select(
          'id, title, metadata, completed_at, assigned_to, profiles(name, first_name, last_name)',
        )
        .eq('tenant_id', tenantId)
        .eq('status', 'completed')
        .isFilter('deleted_at', null)
        .filter('metadata', 'cs', '{"cash_collection_failed": true}');

    final list = List<dynamic>.from(res as List);
    final rows = <FailedCashCollectionRow>[];

    for (final e in list) {
      final map = Map<String, dynamic>.from(e);
      final id = map['id']?.toString().trim();
      if (id == null || id.isEmpty) continue;

      final meta = map['metadata'];
      if (meta == null || meta is! Map) continue;
      final metaMap = Map<String, dynamic>.from(meta);
      if (metaMap['cash_collection_resolved'] == true) continue;

      final amountRaw = metaMap['amount_to_collect'];
      final amount = (amountRaw is num)
          ? amountRaw.toDouble()
          : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
      if (amount == null || amount <= 0) continue;

      final title = (map['title'] as String?)?.trim() ?? '—';
      String workerName = '—';
      final profilesData = map['profiles'];
      if (profilesData != null && profilesData is Map) {
        final p = Map<String, dynamic>.from(profilesData);
        final name = (p['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          workerName = name;
        } else {
          final first = (p['first_name'] as String?)?.trim() ?? '';
          final last = (p['last_name'] as String?)?.trim() ?? '';
          workerName = '$first $last'.trim().isEmpty ? '—' : '$first $last'.trim();
        }
      }

      DateTime? completedAt;
      final raw = map['completed_at'];
      if (raw != null) {
        if (raw is DateTime) {
          completedAt = raw;
        } else if (raw is String) {
          completedAt = DateTime.tryParse(raw);
        }
      }

      rows.add(FailedCashCollectionRow(
        taskId: id,
        taskTitle: title,
        workerName: workerName,
        completedAt: completedAt,
        amountToCollect: amount,
      ));
    }
    return rows;
  } catch (_) {
    return [];
  }
});

/// Označí úkol s nevybranou hotovostí jako vyřešený.
/// Nastaví v metadata: cash_collection_failed: false, cash_collection_resolved: true.
Future<void> resolveFailedCashCollection(WidgetRef ref, String taskId) async {
  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return;

  final res = await SupabaseService.client
      .from('tasks')
      .select('metadata')
      .eq('id', taskId)
      .eq('tenant_id', tenantId)
      .maybeSingle();

  if (res == null) return;

  final resMap = res;
  final existing = resMap['metadata'];
  final meta = existing != null && existing is Map
      ? Map<String, dynamic>.from(existing)
      : <String, dynamic>{};
  meta['cash_collection_failed'] = false;
  meta['cash_collection_resolved'] = true;

  await SupabaseService.client
      .from('tasks')
      .update({'metadata': meta})
      .eq('id', taskId)
      .eq('tenant_id', tenantId);

  ref.invalidate(failedCashCollectionsProvider);
}
