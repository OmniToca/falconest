import 'package:falconest/core/models/apartment_investment_pnl_entry.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Měsíční P&L záznamy majitele (`apartment_investment_pnl_entries`).
///
/// PROČ: Odděleně od metrik investice; upsert využívá unikátní constraint
/// `(apartment_id, entry_month, entry_type)` pro idempotentní uložení z UI.
class OwnerApartmentPnlRepository {
  OwnerApartmentPnlRepository._();

  /// Text v DB při potvrzení převodu nájmu (majitel / admin, režim notification).
  /// PROČ: Shodné s business popisem v SQL migracích u dlouhodobého nájmu.
  static const String kDbDescriptionRentTransferConfirmed = 'Potvrzena platba převodem';

  /// Všechny záznamy pro byt (nejnovější měsíce první).
  static Future<List<ApartmentInvestmentPnlEntry>> fetchByApartmentId(String apartmentId) async {
    if (apartmentId.isEmpty) return [];
    try {
      final res = await SupabaseService.client
          .from('apartment_investment_pnl_entries')
          .select()
          .eq('apartment_id', apartmentId)
          .order('entry_month', ascending: false);
      final list = res as List<dynamic>;
      return list
          .map((e) => ApartmentInvestmentPnlEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      AppLogger.error('OwnerApartmentPnlRepository.fetchByApartmentId', e, st);
      rethrow;
    }
  }

  /// První den kalendářního měsíce v UTC (odpovídá CHECK v DB).
  static DateTime firstDayOfMonthUtc(DateTime referenceUtc) {
    final u = referenceUtc.toUtc();
    return DateTime.utc(u.year, u.month, 1);
  }

  /// Uloží současně příjem a výdaj za [entryMonth] (upsert dvou řádků).
  /// Upsert jednoho řádku `income` (unikátní constraint na měsíc + typ).
  ///
  /// PROČ: Dlouhodobý nájem – potvrzení převodu nebo budoucí rozšíření bez přepisu výdaje.
  static Future<void> upsertIncomeEntry({
    required String apartmentId,
    required DateTime entryMonthFirstDayUtc,
    required double amount,
    String? description,
  }) async {
    if (apartmentId.isEmpty) return;
    final monthStr = _dateToPgDate(entryMonthFirstDayUtc);
    await SupabaseService.client.from('apartment_investment_pnl_entries').upsert(
      <String, dynamic>{
        'apartment_id': apartmentId,
        'entry_month': monthStr,
        'entry_type': 'income',
        'amount': amount,
        if (description != null && description.isNotEmpty) 'description': description,
      },
      onConflict: 'apartment_id,entry_month,entry_type',
    );
  }

  static Future<void> upsertMonthIncomeAndExpense({
    required String apartmentId,
    required DateTime entryMonthFirstDayUtc,
    required double incomeAmount,
    required double expenseAmount,
    String? incomeDescription,
    String? expenseDescription,
  }) async {
    if (apartmentId.isEmpty) return;
    final monthStr = _dateToPgDate(entryMonthFirstDayUtc);

    await SupabaseService.client.from('apartment_investment_pnl_entries').upsert(
      <String, dynamic>{
        'apartment_id': apartmentId,
        'entry_month': monthStr,
        'entry_type': 'income',
        'amount': incomeAmount,
        if (incomeDescription != null && incomeDescription.isNotEmpty) 'description': incomeDescription,
      },
      onConflict: 'apartment_id,entry_month,entry_type',
    );

    await SupabaseService.client.from('apartment_investment_pnl_entries').upsert(
      <String, dynamic>{
        'apartment_id': apartmentId,
        'entry_month': monthStr,
        'entry_type': 'expense',
        'amount': expenseAmount,
        if (expenseDescription != null && expenseDescription.isNotEmpty) 'description': expenseDescription,
      },
      onConflict: 'apartment_id,entry_month,entry_type',
    );
  }

  static String _dateToPgDate(DateTime d) {
    final u = DateTime.utc(d.year, d.month, d.day);
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }

  /// První den měsíce jako `YYYY-MM-DD` pro dotazy na `entry_month` v PostgREST.
  static String monthFirstDayToApiDate(DateTime entryMonthFirstDayUtc) =>
      _dateToPgDate(entryMonthFirstDayUtc);
}
