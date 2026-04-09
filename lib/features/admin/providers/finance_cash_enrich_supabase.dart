import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Obohacení transakcí o kontext z úkolů a klientů přes Supabase (web / admin realtime).
///
/// PROČ: Realtime stream neumožňuje JOIN; po stažení řádků dotáhneme tasks a clients jedním
/// nebo dvěma dotazy. Worker **mobil** používá [enrichCashTransactionsFromDrift] místo tohoto.
Future<List<CashTransactionUIModel>> enrichCashTransactionsWithSupabase(
  String tenantId,
  List<Map<String, dynamic>> rows,
) async {
  final taskIds = rows
      .map((r) => (r['task_id'] as String?)?.trim())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  final taskInfo = <String,
      ({String? apartmentName, String? guestName, String? taskTitle, String? reservationId})>{};

  if (taskIds.isNotEmpty) {
    try {
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select('id, title, reservation_id, apartments(name), reservations(guest_name)')
          .inFilter('id', taskIds)
          .isFilter('deleted_at', null);

      for (final t in res as List) {
        final m = Map<String, dynamic>.from(t);
        final id = (m['id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;

        String? apartmentName;
        String? guestName;
        String? taskTitle;
        String? reservationId;
        final rawRid = m['reservation_id']?.toString().trim();
        if (rawRid != null && rawRid.isNotEmpty) reservationId = rawRid;

        final title = (m['title'] as String?)?.trim();
        if (title != null && title.isNotEmpty) taskTitle = title;

        final apt = m['apartments'];
        if (apt != null && apt is Map) {
          apartmentName = (apt['name'] as String?)?.trim();
          if (apartmentName?.isEmpty == true) apartmentName = null;
        }
        final resData = m['reservations'];
        if (resData != null && resData is Map) {
          guestName = (resData['guest_name'] as String?)?.trim();
          if (guestName?.isEmpty == true) guestName = null;
        }

        taskInfo[id] = (
          apartmentName: apartmentName,
          guestName: guestName,
          taskTitle: taskTitle,
          reservationId: reservationId,
        );
      }
    } catch (_) {
      // Selhání enrichementu nesmí rozbít UI.
    }
  }

  final clientIds = rows
      .map((r) => (r['client_id'] as String?)?.trim())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  final clientInfo = <String, ({String? name, String? clientType})>{};

  if (clientIds.isNotEmpty) {
    try {
      final res = await SupabaseService.safeFrom('clients', tenantId)
          .select('id, name, client_type')
          .inFilter('id', clientIds)
          .isFilter('deleted_at', null);

      for (final c in res as List) {
        final m = Map<String, dynamic>.from(c);
        final id = (m['id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;

        final name = (m['name'] as String?)?.trim();
        final clientType = (m['client_type'] as String?)?.trim();

        clientInfo[id] = (
          name: name != null && name.isNotEmpty ? name : null,
          clientType: clientType != null && clientType.isNotEmpty ? clientType : null,
        );
      }
    } catch (_) {
      // Selhání enrichementu klientů nesmí rozbít UI.
    }
  }

  return rows.map((r) {
    final taskId = (r['task_id'] as String?)?.trim();
    final clientId = (r['client_id'] as String?)?.trim();
    final taskCtx = taskId != null && taskId.isNotEmpty ? taskInfo[taskId] : null;
    final clientCtx = clientId != null && clientId.isNotEmpty ? clientInfo[clientId] : null;

    final rawCopy = Map<String, dynamic>.from(r);
    final existingRid = (rawCopy['reservation_id'] as String?)?.trim();
    final taskReservationId = taskCtx?.reservationId?.trim();
    if ((existingRid == null || existingRid.isEmpty) &&
        taskReservationId != null &&
        taskReservationId.isNotEmpty) {
      rawCopy['reservation_id'] = taskReservationId;
    }

    return CashTransactionUIModel(
      raw: rawCopy,
      apartmentName: taskCtx?.apartmentName,
      guestName: taskCtx?.guestName,
      taskTitle: taskCtx?.taskTitle,
      clientName: clientCtx?.name,
      clientType: clientCtx?.clientType,
    );
  }).toList();
}
