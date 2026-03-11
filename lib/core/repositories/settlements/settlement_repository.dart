import 'package:flutter/foundation.dart';

import 'package:falconest/core/models/task_commission_model.dart';
import 'package:falconest/core/models/task_payout_model.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Výsledek načtení vyúčtování pro jeden úkol.
///
/// PROČ: Oddělená struktura pro výplaty a provize umožňuje UI zobrazit
/// oba typy záznamů v jednom kontextu (historie rozdělení peněz za úkol).
class TaskSettlements {
  const TaskSettlements({
    required this.payouts,
    required this.commissions,
  });

  final List<TaskPayoutModel> payouts;
  final List<TaskCommissionModel> commissions;
}

/// Repozitář pro modul Vyúčtování a Provize (Settlements & Commissions).
///
/// Řeší výdaje agentury: výplaty zaměstnancům a provize externím partnerům z jednotlivých úkolů.
/// Všechny operace jdou přímo do Supabase – RLS zajišťuje multi-tenant izolaci.
class SettlementRepository {
  SettlementRepository._();
  static final SettlementRepository instance = SettlementRepository._();

  /// Hromadně uloží výplaty a provize pro daný úkol.
  ///
  /// PROČ: Admin při schválení vyúčtování zadá výplaty pracovníkům a provize partnerům
  /// v jednom kroku. Metoda vloží všechny záznamy do task_payouts a task_commissions.
  ///
  /// [tenantId] – agentura (z authNotifierProvider.tenantIdForData). Povinné pro multi-tenant.
  /// [taskId] – úkol, ke kterému se vyúčtování váže.
  /// [payouts] – výplaty pracovníkům (profile_id, amount, status). Nové záznamy mohou mít id prázdné.
  /// [commissions] – provize partnerům (client_id, amount, status). Nové záznamy mohou mít id prázdné.
  ///
  /// Vyhazuje [Exception] při chybě Supabase (síť, RLS, validace).
  Future<void> saveSettlement({
    required String tenantId,
    required String taskId,
    required List<TaskPayoutModel> payouts,
    required List<TaskCommissionModel> commissions,
  }) async {
    if (tenantId.trim().isEmpty || taskId.trim().isEmpty) {
      throw ArgumentError('tenantId a taskId jsou povinné.');
    }

    final client = SupabaseService.client;

    // Příprava výplat – pro nové záznamy (id prázdné) vložíme přes insert.
    // PROČ: DB generuje id a časová razítka; nepředáváme je z klienta.
    if (payouts.isNotEmpty) {
      final payoutRows = payouts.map((p) {
        final map = <String, dynamic>{
          'tenant_id': tenantId,
          'task_id': taskId,
          'profile_id': p.profileId,
          'amount': p.amount is int ? p.amount.toDouble() : p.amount,
          'status': p.status.trim().isEmpty ? 'pending' : p.status,
        };
        return map;
      }).toList();

      await client.from('task_payouts').insert(payoutRows);
    }

    // Příprava provizí – buď client_id (partner) nebo profile_id (zaměstnanec).
    if (commissions.isNotEmpty) {
      final commissionRows = commissions.map((c) {
        final map = <String, dynamic>{
          'tenant_id': tenantId,
          'task_id': taskId,
          'amount': c.amount is int ? c.amount.toDouble() : c.amount,
          'status': c.status.trim().isEmpty ? 'pending' : c.status,
        };
        if (c.clientId != null && c.clientId!.trim().isNotEmpty) {
          map['client_id'] = c.clientId;
        }
        if (c.profileId != null && c.profileId!.trim().isNotEmpty) {
          map['profile_id'] = c.profileId;
        }
        return map;
      }).toList();

      await client.from('task_commissions').insert(commissionRows);
    }
  }

  /// Načte již uložené výplaty a provize pro konkrétní úkol.
  ///
  /// PROČ: Při zobrazení historie nebo před schválením můžeme zkontrolovat,
  /// zda už pro úkol existují záznamy (např. aby se předešlo duplicitám).
  ///
  /// Vrací prázdné seznamy, pokud úkol nemá žádné vyúčtování.
  Future<TaskSettlements> getSettlementsForTask(String taskId) async {
    if (taskId.trim().isEmpty) {
      return const TaskSettlements(payouts: [], commissions: []);
    }

    final client = SupabaseService.client;

    // Paralelní načtení výplat a provizí – zrychlení oproti sekvenčnímu volání.
    final payoutsFuture = client
        .from('task_payouts')
        .select()
        .eq('task_id', taskId);

    final commissionsFuture = client
        .from('task_commissions')
        .select()
        .eq('task_id', taskId);

    final results = await Future.wait([payoutsFuture, commissionsFuture]);

    final payoutList = (results[0] as List)
        .map((e) => TaskPayoutModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final commissionList = (results[1] as List)
        .map((e) => TaskCommissionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return TaskSettlements(payouts: payoutList, commissions: commissionList);
  }

  /// Označí výplaty jako vyplacené – hromadný update status na 'paid'.
  ///
  /// PROČ: Admin při hromadném vyplácení (Payroll) označí několik výplat najednou.
  /// [payoutIds] – seznam UUID z task_payouts. Prázdný seznam se ignoruje.
  Future<void> markPayoutsAsPaid(List<String> payoutIds) async {
    if (payoutIds.isEmpty) return;
    final ids = payoutIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;

    await SupabaseService.client
        .from('task_payouts')
        .update({'status': 'paid', 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids);
  }

  /// Označí provize jako vyplacené – hromadný update status na 'paid'.
  ///
  /// PROČ: Admin při hromadném vyplácení (Payroll) označí několik provizí najednou.
  /// [commissionIds] – seznam UUID z task_commissions. Prázdný seznam se ignoruje.
  Future<void> markCommissionsAsPaid(List<String> commissionIds) async {
    if (commissionIds.isEmpty) return;
    final ids = commissionIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;

    await SupabaseService.client
        .from('task_commissions')
        .update({'status': 'paid', 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids);
  }

  /// Načte pending výplaty s jménem pracovníka a údaji úkolu (join profiles + tasks).
  ///
  /// PROČ: Pro pohled "K výplatě" seskupujeme podle zaměstnance a potřebujeme
  /// rozpad po úkolech (název, datum, částka) a hodnotu úkolu pro výpočet marže.
  Future<List<Map<String, dynamic>>> getPendingPayoutsWithProfile(String tenantId) async {
    if (tenantId.trim().isEmpty) return [];
    try {
      final res = await SupabaseService.client
          .from('task_payouts')
          .select('id, profile_id, amount, task_id, profiles(name, first_name, last_name), tasks(title, custom_title, completed_at, scheduled_start, metadata)')
          .eq('tenant_id', tenantId)
          .eq('status', 'pending');
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Načte pending provize s client_id, názvem partnera a údaji úkolu (join clients + tasks).
  ///
  /// PROČ: Pro pohled "K výplatě" – rozpad po úkolech a výpočet marže agentury.
  Future<List<Map<String, dynamic>>> getPendingCommissionsWithClient(String tenantId) async {
    if (tenantId.trim().isEmpty) return [];
    try {
      final res = await SupabaseService.client
          .from('task_commissions')
          .select('id, client_id, amount, task_id, clients(name), tasks(title, custom_title, completed_at, scheduled_start, metadata)')
          .eq('tenant_id', tenantId)
          .eq('status', 'pending')
          .not('client_id', 'is', null);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Načte pending provize s profile_id, jménem zaměstnance a údaji úkolu (join profiles + tasks).
  ///
  /// PROČ: Provize pro zaměstnance – sloučí se do PayoutGroup včetně rozpadu po úkolech.
  Future<List<Map<String, dynamic>>> getPendingCommissionsWithProfile(String tenantId) async {
    if (tenantId.trim().isEmpty) return [];
    try {
      final res = await SupabaseService.client
          .from('task_commissions')
          .select('id, profile_id, amount, task_id, profiles(name, first_name, last_name), tasks(title, custom_title, completed_at, scheduled_start, metadata)')
          .eq('tenant_id', tenantId)
          .eq('status', 'pending')
          .not('profile_id', 'is', null);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Načte provize vázané na klienta (client_id) – pro záložku Finance v detailu klienta.
  ///
  /// PROČ: V detailu klienta zobrazíme historii vyplacených a čekajících provizí
  /// z task_commissions. Řazení od nejnovějších. Join na tasks pro název úkolu.
  ///
  /// [tenantId] – agentura. [clientId] – ID klienta z tabulky clients.
  /// Vrací seznam map: id, task_id, amount, status, created_at, task_title.
  Future<List<Map<String, dynamic>>> getCommissionsForClient(
    String tenantId,
    String clientId,
  ) async {
    if (tenantId.trim().isEmpty || clientId.trim().isEmpty) return [];

    try {
      final res = await SupabaseService.client
          .from('task_commissions')
          .select('id, task_id, amount, status, created_at, tasks(title, custom_title)')
          .eq('tenant_id', tenantId)
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final list = res as List;
      final result = <Map<String, dynamic>>[];
      for (final e in list) {
        final map = Map<String, dynamic>.from(e as Map);
        final tasksData = map['tasks'];
        String taskTitle = '';
        if (tasksData is Map) {
          final t = Map<String, dynamic>.from(tasksData);
          final custom = (t['custom_title'] as String?)?.trim();
          final title = (t['title'] as String?)?.trim();
          taskTitle = (custom != null && custom.isNotEmpty) ? custom : (title ?? '');
        }
        result.add({
          'id': map['id'],
          'task_id': map['task_id'],
          'amount': map['amount'],
          'status': map['status'],
          'created_at': map['created_at'],
          'task_title': taskTitle.isEmpty ? '—' : taskTitle,
        });
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Načte provize pro daného pracovníka (profile_id), včetně názvu úkolu a data dokončení.
  ///
  /// PROČ: Worker pohled „Moje výdělky“ – zaměstnanec vidí i své provize (např. za
  /// sehnaného klienta). RLS na task_commissions filtruje podle profile_id.
  ///
  /// [tenantId] – agentura. [profileId] – profil přihlášeného pracovníka.
  /// Vrací seznam map s klíči: id, task_id, amount, status, created_at, task_title, completed_at.
  /// Pole [task_title] je surový název úkolu – v UI se prefixuje např. „Provize: “.
  Future<List<Map<String, dynamic>>> getMyCommissions(String tenantId, String profileId) async {
    if (tenantId.trim().isEmpty || profileId.trim().isEmpty) return [];

    try {
      final res = await SupabaseService.client
          .from('task_commissions')
          .select('id, task_id, amount, status, created_at, tasks(title, custom_title, completed_at)')
          .eq('tenant_id', tenantId)
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);

      final list = res as List;
      final result = <Map<String, dynamic>>[];
      for (final e in list) {
        final map = Map<String, dynamic>.from(e as Map);
        final tasksData = map['tasks'];
        String taskTitle = '';
        DateTime? completedAt;
        if (tasksData is Map) {
          final t = Map<String, dynamic>.from(tasksData);
          final custom = (t['custom_title'] as String?)?.trim();
          final title = (t['title'] as String?)?.trim();
          taskTitle = (custom != null && custom.isNotEmpty) ? custom : (title ?? '');
          final ca = t['completed_at'];
          if (ca != null) completedAt = DateTime.tryParse(ca.toString());
        }
        result.add({
          'id': map['id'],
          'task_id': map['task_id'],
          'amount': map['amount'],
          'status': map['status'],
          'created_at': map['created_at'],
          'task_title': taskTitle.isEmpty ? '—' : taskTitle,
          'completed_at': completedAt?.toIso8601String(),
        });
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Načte výplaty pro daného pracovníka včetně názvu úkolu a data dokončení.
  ///
  /// PROČ: Worker pohled „Moje výdělky“ – zaměstnanec vidí své výplaty, název úkolu
  /// a datum dokončení. RLS na task_payouts umožňuje pracovníkovi číst jen své záznamy.
  ///
  /// [tenantId] – agentura. [profileId] – profil přihlášeného pracovníka.
  /// Vrací seznam map s klíči: id, task_id, amount, status, task_title, completed_at.
  Future<List<Map<String, dynamic>>> getMyPayouts(String tenantId, String profileId) async {
    if (tenantId.trim().isEmpty || profileId.trim().isEmpty) return [];

    try {
      final res = await SupabaseService.client
          .from('task_payouts')
          .select('id, task_id, amount, status, created_at, tasks(title, custom_title, completed_at)')
          .eq('tenant_id', tenantId)
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);

      final list = res as List;
      final result = <Map<String, dynamic>>[];
      for (final e in list) {
        final map = Map<String, dynamic>.from(e as Map);
        final tasksData = map['tasks'];
        String taskTitle = '';
        DateTime? completedAt;
        if (tasksData is Map) {
          final t = Map<String, dynamic>.from(tasksData);
          final custom = (t['custom_title'] as String?)?.trim();
          final title = (t['title'] as String?)?.trim();
          taskTitle = (custom != null && custom.isNotEmpty) ? custom : (title ?? '');
          final ca = t['completed_at'];
          if (ca != null) completedAt = DateTime.tryParse(ca.toString());
        }
        result.add({
          'id': map['id'],
          'task_id': map['task_id'],
          'amount': map['amount'],
          'status': map['status'],
          'created_at': map['created_at'],
          'task_title': taskTitle.isEmpty ? '—' : taskTitle,
          'completed_at': completedAt?.toIso8601String(),
        });
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Načte zmražené snapshoty výplat pro daný měsíc z tabulky [payout_snapshots].
  ///
  /// PROČ: Historie výplat čte výhradně z uzamčených snapshotů (jako billing_snapshots u fakturace).
  /// Žádné dynamické joinování task_payouts/task_commissions – ochrana před změnou historických dat.
  ///
  /// [tenantId] – agentura. [month] – první den měsíce (rok a měsíc).
  /// Vrací surové řádky z DB: is_employee, profile_id?, client_id?, recipient_name, total_amount, items_data.
  /// Mapování na [PayoutGroup] provádí provider (aby repo nezávisel na feature vrstvě).
  Future<List<Map<String, dynamic>>> getPayoutSnapshotsByMonth(
    String tenantId,
    DateTime month,
  ) async {
    if (tenantId.trim().isEmpty) return [];

    final period = DateTime.utc(month.year, month.month, 1);
    final periodStr = '${period.year}-${period.month.toString().padLeft(2, '0')}-01';

    try {
      final res = await SupabaseService.client
          .from('payout_snapshots')
          .select('id, is_employee, profile_id, client_id, recipient_name, total_amount, items_data')
          .eq('tenant_id', tenantId)
          .eq('payout_period', periodStr)
          .order('recipient_name');

      final list = (res as List).cast<Map<String, dynamic>>();
      return list;
    } catch (e, st) {
      debugPrint('getPayoutSnapshotsByMonth ERROR: $e');
      debugPrint('getPayoutSnapshotsByMonth STACK: $st');
      rethrow;
    }
  }

  /// Vloží nebo sloučí jeden snapshot výplaty do [payout_snapshots] (UPSERT podle příjemce a měsíce).
  ///
  /// PROČ: Po kliknutí „Vyplatit“ v záložce K výplatě musíme kromě statusu paid zapsat
  /// uzamčený záznam do payout_snapshots, aby Historie výplat měla co zobrazit.
  /// Při doplacení ve stejném měsíci se položky a částka sloučí do existujícího řádku.
  ///
  /// [itemsData] – seznam map: [{ "task_id", "task_title", "date" (ISO nebo null), "amount" }].
  /// Může být prázdný (např. skupina bez rozpadu po úkolech) – snapshot se i tak uloží.
  Future<void> upsertPayoutSnapshot({
    required String tenantId,
    required DateTime payoutPeriodFirstDay,
    required bool isEmployee,
    required String? profileId,
    required String? clientId,
    required String recipientName,
    required double totalAmount,
    required List<Map<String, dynamic>> itemsData,
    required String lockedByProfileId,
  }) async {
    if (tenantId.trim().isEmpty || lockedByProfileId.trim().isEmpty) {
      throw ArgumentError('tenantId a lockedByProfileId jsou povinné.');
    }
    if (isEmployee && (profileId == null || profileId.trim().isEmpty)) {
      throw ArgumentError('U zaměstnance je profileId povinné.');
    }
    if (!isEmployee && (clientId == null || clientId.trim().isEmpty)) {
      throw ArgumentError('U partnera je clientId povinné.');
    }

    final periodStr =
        '${payoutPeriodFirstDay.year}-${payoutPeriodFirstDay.month.toString().padLeft(2, '0')}-01';
    final client = SupabaseService.client;

    // Načtení existujícího řádku pro tento měsíc a příjemce (pro merge při doplacení).
    final existingRaw = isEmployee
        ? await client
            .from('payout_snapshots')
            .select('id, total_amount, items_data')
            .eq('tenant_id', tenantId)
            .eq('payout_period', periodStr)
            .eq('profile_id', profileId!)
            .maybeSingle()
        : await client
            .from('payout_snapshots')
            .select('id, total_amount, items_data')
            .eq('tenant_id', tenantId)
            .eq('payout_period', periodStr)
            .eq('client_id', clientId!)
            .maybeSingle();
    final existing = existingRaw != null ? Map<String, dynamic>.from(existingRaw as Map) : null;

    if (existing != null && existing['id'] != null) {
      // Sloučení: přidat položky a částku k existujícímu snapshotu.
      final existingAmount = (existing['total_amount'] is num)
          ? (existing['total_amount'] as num).toDouble()
          : 0.0;
      final existingItems = existing['items_data'] is List
          ? List<Map<String, dynamic>>.from(
              (existing['items_data'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : <Map<String, dynamic>>[];
      final mergedItems = [...existingItems, ...itemsData];
      final mergedAmount = existingAmount + totalAmount;

      await client.from('payout_snapshots').update({
        'total_amount': mergedAmount,
        'items_data': mergedItems,
        'locked_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', existing['id']);
    } else {
      // Nový řádek.
      await client.from('payout_snapshots').insert({
        'tenant_id': tenantId,
        'payout_period': periodStr,
        'is_employee': isEmployee,
        'profile_id': isEmployee ? profileId : null,
        'client_id': isEmployee ? null : clientId,
        'recipient_name': recipientName.trim().isEmpty ? '—' : recipientName,
        'total_amount': totalAmount,
        'items_data': itemsData,
        'locked_by': lockedByProfileId,
      });
    }
  }

  /// Příprava pro budoucí uzamčení měsíce výplat – zápis snapshotů do [payout_snapshots].
  ///
  /// PROČ: Při akci „Uzamknout měsíc“ se sestaví data z aktuálních paid záznamů
  /// a vloží do payout_snapshots (RPC nebo batch insert). Zatím jen kostra – implementace
  /// doplní volání Supabase (insert řádků nebo RPC lock_payout_month).
  Future<void> lockPayoutMonth({
    required String tenantId,
    required DateTime month,
    required String lockedByProfileId,
    required List<Map<String, dynamic>> snapshotRows,
  }) async {
    if (tenantId.trim().isEmpty || lockedByProfileId.trim().isEmpty) {
      throw ArgumentError('tenantId a lockedByProfileId jsou povinné.');
    }
    if (snapshotRows.isEmpty) return;

    final period = DateTime.utc(month.year, month.month, 1);
    final periodStr = '${period.year}-${period.month.toString().padLeft(2, '0')}-01';
    final client = SupabaseService.client;

    final rows = snapshotRows.map((row) {
      return {
        'tenant_id': tenantId,
        'payout_period': periodStr,
        'is_employee': row['is_employee'] as bool,
        'profile_id': row['profile_id'] as String?,
        'client_id': row['client_id'] as String?,
        'recipient_name': row['recipient_name'] as String,
        'total_amount': (row['total_amount'] as num).toDouble(),
        'items_data': row['items_data'],
        'locked_by': lockedByProfileId,
      };
    }).toList();

    await client.from('payout_snapshots').insert(rows);
  }

  /// Načte surové řádky úkolů pro frontu „Ke schválení“ – dokončené úkoly bez výplat/provizí.
  ///
  /// PROČ: Fronta úkolů ve Financích musí být globální INBOX – zobrazovat VŠECHNY dokončené
  /// úkoly bez vyúčtování, bez ohledu na vybraný měsíc v kalendáři. Prevence ztráty nevyplacených
  /// úkolů při přelomu měsíce (riziko nevyplacení mzdy). Načítání přes tento repozitář je
  /// nezávislé na [watchTasksRawForMonth] a [selectedTaskMonthProvider].
  ///
  /// LOGIKA: Dokončené úkoly (status in completed/done/hotovo/dokončeno), deleted_at IS NULL,
  /// vyloučíme ty, které už mají záznam v task_payouts. Řazení podle completed_at DESC (null na konci),
  /// limit 500. RLS zajišťuje tenant_id.
  ///
  /// [tenantId] – agentura. Vrací List<Map> pro konverzi na TaskRow v provideru (s apartmentById, nameByProfileId).
  Future<List<Map<String, dynamic>>> getAllPendingSettlementTasks(String tenantId) async {
    if (tenantId.trim().isEmpty) return [];

    try {
      final excludeIds = await getTaskIdsWithPayouts(tenantId);

      final res = await SupabaseService.client
          .from('tasks')
          .select()
          .eq('tenant_id', tenantId)
          .isFilter('deleted_at', null)
          .inFilter('status', ['completed', 'done', 'hotovo', 'dokončeno'])
          .order('completed_at', ascending: false)
          .limit(500);

      final list = (res as List).cast<Map<String, dynamic>>();
      return list.where((r) {
        final id = (r['id'] as String?)?.trim();
        return id != null && id.isNotEmpty && !excludeIds.contains(id);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Načte množinu ID úkolů, které už mají záznam v task_payouts.
  ///
  /// PROČ: Provider fronty "Ke schválení" vyfiltruje dokončené úkoly tak,
  /// aby nezobrazoval ty, u kterých Admin již rozdělil peníze.
  ///
  /// [tenantId] – agentura. RLS na task_payouts zajistí, že vidíme jen data tenanta.
  Future<Set<String>> getTaskIdsWithPayouts(String tenantId) async {
    if (tenantId.trim().isEmpty) return {};

    try {
      final res = await SupabaseService.client
          .from('task_payouts')
          .select('task_id')
          .eq('tenant_id', tenantId);

      final list = res as List;
      final ids = <String>{};
      for (final e in list) {
        final map = e as Map;
        final tid = (map['task_id'] as String?)?.trim();
        if (tid != null && tid.isNotEmpty) ids.add(tid);
      }
      return ids;
    } catch (_) {
      return {};
    }
  }

  /// Načte množinu ID úkolů, které už mají záznam v task_commissions.
  ///
  /// PROČ: Finanční zámek – úkoly s provizemi (výplaty nebo provize) nelze dále upravovat,
  /// aby nedošlo k rozbití účetnictví. Spojení s getTaskIdsWithPayouts dává úplnou množinu uzamčených úkolů.
  ///
  /// [tenantId] – agentura. RLS na task_commissions zajistí, že vidíme jen data tenanta.
  Future<Set<String>> getTaskIdsWithCommissions(String tenantId) async {
    if (tenantId.trim().isEmpty) return {};

    try {
      final res = await SupabaseService.client
          .from('task_commissions')
          .select('task_id')
          .eq('tenant_id', tenantId);

      final list = res as List;
      final ids = <String>{};
      for (final e in list) {
        final map = e as Map;
        final tid = (map['task_id'] as String?)?.trim();
        if (tid != null && tid.isNotEmpty) ids.add(tid);
      }
      return ids;
    } catch (_) {
      return {};
    }
  }
}
