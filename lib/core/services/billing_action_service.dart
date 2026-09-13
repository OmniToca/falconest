import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';

/// Služba pro akce modulu Fakturace – uzamčení měsíce a zápis snapshotů.
///
/// PROČ SNAPSHOTOVÁNÍ: Místo generování a ukládání fyzických PDF při uzamčení
/// ukládáme přesná data (ceny, úkoly, výdaje) jako JSONB do `billing_snapshots`.
/// Majitelé si z těchto dat mohou v Klientské zóně kdykoliv vygenerovat PDF On-Demand.
///
/// PROČ UPSERT: Unikátní index na (tenant_id, client_id, billing_period) zaručuje
/// jeden snapshot na klienta a měsíc. Při opakovaném kliknutí (např. chyba sítě)
/// upsert přepíše existující záznam místo vzniku duplicity. Idempotentní chování.
class BillingActionService {
  BillingActionService._();

  /// Uzamče měsíc fakturace: vytvoří JSON snapshoty pro každého klienta,
  /// uloží je do billing_snapshots a označí úkoly jako vyfakturované (invoiced_at).
  ///
  /// [snapshot_data] obsahuje:
  /// - client_name, currency – metadata pro PDF.
  /// - total_to_invoice, total_expenses, final_to_invoice – součty.
  /// - items – pole úkolů (task_id, title, title_i18n, scheduled_start, completed_at,
  ///   charged_price, payer_type, reservation_id, media_urls,
  ///   assigned_to, assigned_user_ids, requires_photo).
  /// Zmražení zaručuje neměnnost – budoucí změny ceníku neovlivní historická vyúčtování.
  static Future<void> lockBillingMonth(
    List<BillingGroup> groups,
    DateTime month,
    String tenantId,
    String profileId,
    String currency,
  ) async {
    if (tenantId.isEmpty || profileId.isEmpty) return;

    // Posbírej všechna taskId ze všech skupin (pro označení vyfakturovaných). Skupiny mohou být i jen s paušálem (0 úkolů).
    final allTaskIds = <String>{};
    for (final group in groups) {
      for (final task in group.tasks) {
        if (task.taskId.trim().isNotEmpty) {
          allTaskIds.add(task.taskId);
        }
      }
    }

    final billingPeriod = DateTime(month.year, month.month, 1);
    final billingPeriodStr =
        '${billingPeriod.year}-${billingPeriod.month.toString().padLeft(2, '0')}-01';
    final lockedAt = DateTime.now().toUtc().toIso8601String();

    // Vytvoř snapshoty pouze pro skupiny s platným client_id (UUID).
    // Skupina 'external' nemá klienta v DB – přeskočíme ji.
    final snapshotsToInsert = <Map<String, dynamic>>[];
    for (final group in groups) {
      if (group.groupKey == 'external') continue;
      // Ověření, že groupKey vypadá jako UUID (36 znaků včetně pomlček)
      if (group.groupKey.length != 36) continue;

      final items = group.tasks.map((t) {
        return <String, dynamic>{
          'task_id': t.taskId,
          'title': t.title,
          if (t.titleI18n != null && t.titleI18n!.isNotEmpty) 'title_i18n': t.titleI18n,
          'scheduled_start': t.scheduledStart?.toUtc().toIso8601String(),
          'completed_at': t.completedAt?.toUtc().toIso8601String(),
          'charged_price': t.chargedPrice,
          'payer_type': t.payerType,
          'reservation_id': t.reservationId,
          'guest_name': t.guestName,
          'reservation_start': t.reservationStart?.toUtc().toIso8601String(),
          'reservation_end': t.reservationEnd?.toUtc().toIso8601String(),
          'media_urls': t.mediaUrls,
          'cash_shortfall_missing_amount': t.cashShortfallMissingAmount,
          'is_shortfall_resolved': t.isShortfallResolved,
          'assigned_to': t.assignedTo,
          'assigned_user_ids': t.assignedUserIds,
          'requires_photo': t.requiresPhoto,
          if (t.apartmentId != null && t.apartmentId!.trim().isNotEmpty)
            'apartment_id': t.apartmentId!.trim(),
          if (t.apartmentName != null && t.apartmentName!.trim().isNotEmpty)
            'apartment_name': t.apartmentName!.trim(),
        };
      }).toList();

      final expensesData = group.expenses.map((e) => <String, dynamic>{
            'id': e.id,
            'date': e.date.toUtc().toIso8601String(),
            'description': e.description,
            'amount': e.amount,
            'media_urls': e.mediaUrls,
          }).toList();

      final snapshotData = <String, dynamic>{
        'client_name': group.groupName,
        'currency': currency,
        'total_to_invoice': group.totalToInvoice,
        'total_paid_by_guest': group.totalPaidByGuest,
        'total_expenses': group.totalExpenses,
        'expenses': expensesData,
        'final_to_invoice': group.finalToInvoice,
        'items': items,
        'monthly_management_fee': group.monthlyManagementFee,
      };

      snapshotsToInsert.add({
        'tenant_id': tenantId,
        'client_id': group.groupKey,
        'billing_period': billingPeriodStr,
        'snapshot_data': snapshotData,
        'locked_at': lockedAt,
        'locked_by': profileId,
      });
    }

    if (snapshotsToInsert.isEmpty) {
      // Žádné platné skupiny (jen external?) – přesto označíme úkoly, pokud nějaké jsou
      await _markTasksInvoiced(tenantId, allTaskIds.toList(), lockedAt);
      return;
    }

    try {
      final safeSnapshots = snapshotsToInsert
          .map((r) => SupabaseService.safeInsertPayload(tenantId, Map<String, dynamic>.from(r)))
          .toList();
      await SupabaseService.safeFrom('billing_snapshots', tenantId).upsert(
        safeSnapshots,
        onConflict: 'tenant_id,client_id,billing_period',
      );

      // Označ úkoly jako vyfakturované (allTaskIds může být prázdné u měsíců jen s paušály)
      await _markTasksInvoiced(tenantId, allTaskIds.toList(), lockedAt);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _markTasksInvoiced(
    String tenantId,
    List<String> taskIds,
    String invoicedAt,
  ) async {
    if (taskIds.isEmpty) return;

    await SupabaseService.safeFrom('tasks', tenantId)
        .update({'invoiced_at': invoicedAt})
        .inFilter('id', taskIds);
  }
}
