/// Mobilní implementace WorkerSyncService – čte/zapisuje výhradně do Drift (SQLite).
///
/// Isar byl kompletně odstraněn – nestabilní na iOS ("Collection id is invalid").
/// Všechna data pro Worker UI jsou nyní v relační SQLite databázi.
library;
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:falconest/core/database/drift/database_provider.dart' show DriftSyncRepos;
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

class WorkerSyncService {
  WorkerSyncService._();

  static Future<void> syncTasksFromSupabase(
    String workerId,
    String tenantId, {
    void Function(String)? onSyncError,
    DriftSyncRepos? driftRepos,
    void Function()? onSmartMergeApplied,
  }) async {
    try {
      if (workerId.isEmpty || tenantId.isEmpty) return;

      await pushPendingUpdates(
        tenantId,
        onSyncError: onSyncError,
        driftRepos: driftRepos,
        onSmartMergeApplied: onSmartMergeApplied,
      );

      if (driftRepos == null) return;

      // PROČ: Stahujeme měnu tenanta – Worker UI ji potřebuje offline (formátování hotovosti).
      await _syncTenant(tenantId, driftRepos);

      // PROČ: Modul Communication – šablony zpráv pro řidiče. Full Replace.
      await _syncMessageTemplates(tenantId, driftRepos);

      // PROČ: Vizitka v draweru čte Drift – bez tohoto kroku by offline chybělo jméno/e-mail z profiles.
      await _syncUserProfileCache(tenantId, driftRepos, onSyncError: onSyncError);

      final now = DateTime.now().toUtc();
      final pastLimit = now.subtract(const Duration(days: 7)).toIso8601String();
      final futureLimit = now.add(const Duration(days: 14)).toIso8601String();

      // PROČ: Worker vidí úkol, pokud je v assigned_to NEBO v assigned_user_ids.
      final tasksData = await SupabaseService.safeFrom('tasks', tenantId)
          .select('id, tenant_id, apartment_id, client_id, custom_location, custom_title, reference_number, reservation_id, assigned_to, assigned_user_ids, title, description, task_type, scheduled_start, due_date, unassigned_info, service_id, status, photo_url, metadata, media_urls, started_at, completed_at, invoiced_at')
          .or('assigned_to.eq.$workerId,assigned_user_ids.cs.{$workerId}')
          .neq('status', 'pending')
          .isFilter('deleted_at', null)
          .isFilter('invoiced_at', null)
          .gte('scheduled_start', pastLimit)
          .lte('scheduled_start', futureLimit)
          .order('scheduled_start', ascending: true);

      final tasksList = tasksData is List ? List<dynamic>.from(tasksData) : <dynamic>[];
      if (tasksList.isEmpty) {
        await _clearAndWrite(tenantId, workerId, [], [], [], [], driftRepos, onSyncError: onSyncError);
        // PROČ: Výdělky nezávisí na otevřených úkolech – musí se stáhnout i při prázdném seznamu úkolů.
        await _syncWorkerEarnings(tenantId, workerId, driftRepos, onSyncError: onSyncError);
        await _syncStaffAbsences(tenantId, workerId, driftRepos, onSyncError: onSyncError);
        await _syncEmployeeCash(tenantId, workerId, driftRepos, onSyncError: onSyncError);
        return;
      }

      final apartmentIds = <String>{};
      final reservationIds = <String>{};
      final clientIds = <String>{};
      for (final t in tasksList) {
        final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
        final aptId = map['apartment_id']?.toString().trim();
        if (aptId != null && aptId.isNotEmpty) apartmentIds.add(aptId);
        final resId = map['reservation_id']?.toString().trim();
        if (resId != null && resId.isNotEmpty) reservationIds.add(resId);
        final cId = map['client_id']?.toString().trim();
        if (cId != null && cId.isNotEmpty) clientIds.add(cId);
      }

      List<dynamic> apartmentsData = [];
      if (apartmentIds.isNotEmpty) {
        apartmentsData = await SupabaseService.safeFrom('apartments', tenantId)
            .select(
              'id, tenant_id, name, address, code, keybox, owner_notes, check_in_time, check_out_time, '
              'zone_id, parking_instructions, investment_tracking_enabled, rental_mode, lease_start_date, lease_end_date, '
              'rent_amount, rent_due_day, rent_collection_mode, rent_task_assignee_id',
            )
            .inFilter('id', apartmentIds.toList())
            .isFilter('deleted_at', null);
        apartmentsData = List<dynamic>.from(apartmentsData);
      }

      List<dynamic> reservationsData = [];
      if (reservationIds.isNotEmpty) {
        reservationsData = await SupabaseService.safeFrom('reservations', tenantId)
            .select(
              'id, tenant_id, updated_at, reference_number, status, guest_name, guest_phone, '
              'special_requests, guest_language, start_date, end_date',
            )
            .inFilter('id', reservationIds.toList())
            .isFilter('deleted_at', null);
        reservationsData = List<dynamic>.from(reservationsData);
      }

      List<dynamic> clientsData = [];
      if (clientIds.isNotEmpty) {
        clientsData = await SupabaseService.safeFrom('clients', tenantId)
            .select('id, tenant_id, name, phone')
            .inFilter('id', clientIds.toList())
            .isFilter('deleted_at', null);
        clientsData = List<dynamic>.from(clientsData);
      }

      await _clearAndWrite(
        tenantId,
        workerId,
        tasksList,
        apartmentsData,
        reservationsData,
        clientsData,
        driftRepos,
        onSyncError: onSyncError,
      );
      await _syncWorkerEarnings(tenantId, workerId, driftRepos, onSyncError: onSyncError);
      await _syncStaffAbsences(tenantId, workerId, driftRepos, onSyncError: onSyncError);
      await _syncEmployeeCash(tenantId, workerId, driftRepos, onSyncError: onSyncError);
    } catch (e, st) {
      onSyncError?.call(e.toString());
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerSyncService.syncTasksFromSupabase ERROR: $e');
        // ignore: avoid_print
        print(st);
      }
    }
  }

  static Future<void> _syncTenant(String tenantId, DriftSyncRepos driftRepos) async {
    if (tenantId.isEmpty) return;
    try {
      final tenantRes = await SupabaseService.client
          .from('tenants')
          .select('id, currency')
          .eq('id', tenantId)
          .maybeSingle();
      if (tenantRes == null) return;
      final map = Map<String, dynamic>.from(tenantRes as Map);
      if (map.isEmpty) return;
      await driftRepos.tenant.upsertFromSupabaseMap(map);
    } catch (e, st) {
      AppLogger.error('WorkerSyncService: zápis tenanta do Driftu po stažení z Supabase selhal', e, st);
    }
  }

  static Future<void> _syncMessageTemplates(String tenantId, DriftSyncRepos driftRepos) async {
    if (tenantId.isEmpty) return;
    try {
      final templatesData = await SupabaseService.safeFrom('tenant_message_templates', tenantId)
          .select(
            'id, tenant_id, key, name, channel, email_subject, translations, trigger_context, order_index',
          )
          .isFilter('deleted_at', null)
          .order('order_index', ascending: true);

      final templatesList = List<dynamic>.from(templatesData as List);

      await driftRepos.messageTemplate.clearForTenant(tenantId);
      for (final raw in templatesList) {
        final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        if (map.isEmpty) continue;
        final supabaseId = map['id']?.toString().trim();
        if (supabaseId == null || supabaseId.isEmpty) continue;
        await driftRepos.messageTemplate.upsertFromSupabaseMap(map);
      }
    } catch (e, st) {
      AppLogger.error('WorkerSyncService: synchronizace šablon zpráv (tenant_message_templates) do Driftu selhala', e, st);
    }
  }

  /// Stejný výběr sloupců jako hlavní worker sync úkolů – pro doplnění řádků jen kvůli JOIN ve výdělcích.
  static const String _payoutRelatedTasksSelect =
      'id, tenant_id, apartment_id, client_id, custom_location, custom_title, reference_number, reservation_id, assigned_to, assigned_user_ids, title, description, task_type, scheduled_start, due_date, unassigned_info, service_id, status, photo_url, metadata, media_urls, started_at, completed_at, invoiced_at';

  /// Doplní do Driftu úkoly odkazované z výplat/provizí, které nejsou v hlavním okně syncu (dokončené / mimo rozsah).
  ///
  /// PROČ: Hlavní dotaz na úkoly filtruje časové okno a stav; výplata může odkazovat na starší úkol.
  /// Bez tohoto kroku JOIN v [DriftTaskPayoutRepository] vrací null a UI ukazuje prázdný název.
  static Future<void> _upsertTasksForPayoutReferences(
    String tenantId,
    List<dynamic> payoutsRaw,
    List<dynamic> commissionsRaw,
    DriftSyncRepos driftRepos,
  ) async {
    if (tenantId.isEmpty) return;
    final ids = <String>{};
    void collect(List<dynamic> list) {
      for (final raw in list) {
        final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final tid = map['task_id']?.toString().trim();
        if (tid != null && tid.isNotEmpty) ids.add(tid);
      }
    }
    collect(payoutsRaw);
    collect(commissionsRaw);
    if (ids.isEmpty) return;
    final idList = ids.toList();
    for (var i = 0; i < idList.length; i += _syncInFilterChunkSize) {
      final end = i + _syncInFilterChunkSize > idList.length ? idList.length : i + _syncInFilterChunkSize;
      final chunk = idList.sublist(i, end);
      try {
        final data = await SupabaseService.safeFrom('tasks', tenantId)
            .select(_payoutRelatedTasksSelect)
            .inFilter('id', chunk)
            .isFilter('deleted_at', null);
        final fetched = data is List ? List<dynamic>.from(data) : <dynamic>[];
        for (final t in fetched) {
          final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
          if (map.isEmpty) continue;
          await driftRepos.task.upsertTaskFromSupabaseMap(map);
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('WorkerSyncService._upsertTasksForPayoutReferences: $e');
        }
      }
    }
  }

  /// Stáhne `task_payouts` a `task_commissions` pro přihlášeného pracovníka a uloží je do Driftu.
  ///
  /// PROČ: Obrazovka „Moje výdělky“ je offline-first – UI nikdy nevolá Supabase, jen čte SQLite.
  /// Data se obnovují společně se sync úkolů (stejná session v terénu).
  static Future<void> _syncWorkerEarnings(
    String tenantId,
    String workerId,
    DriftSyncRepos driftRepos, {
    void Function(String)? onSyncError,
  }) async {
    if (tenantId.isEmpty || workerId.isEmpty) return;
    try {
      final payoutsRaw = await SupabaseService.safeFrom('task_payouts', tenantId)
          .select('id, tenant_id, task_id, profile_id, amount, status, created_at, updated_at')
          .eq('profile_id', workerId)
          .order('created_at', ascending: false);

      final commissionsRaw = await SupabaseService.safeFrom('task_commissions', tenantId)
          .select('id, tenant_id, task_id, profile_id, client_id, amount, status, created_at, updated_at')
          .eq('profile_id', workerId)
          .order('created_at', ascending: false);

      final listP = payoutsRaw is List ? List<dynamic>.from(payoutsRaw) : <dynamic>[];
      final listC = commissionsRaw is List ? List<dynamic>.from(commissionsRaw) : <dynamic>[];

      await driftRepos.taskPayout.replaceFromSupabaseForProfile(tenantId, workerId, listP, listC);
      await _upsertTasksForPayoutReferences(tenantId, listP, listC, driftRepos);
    } catch (e, st) {
      onSyncError?.call('Earnings sync: $e');
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerSyncService._syncWorkerEarnings ERROR: $e');
        // ignore: avoid_print
        print(st);
      }
    }
  }

  /// Stáhne řádek `profiles` pro aktuální `auth.uid()` a uloží ho do Drift cache.
  ///
  /// PROČ: Stejný zdroj jako webový provider, ale zápis jen při synci – UI čte výhradně SQLite.
  /// Dotaz přes globální klienta jako dříve (RLS podle přihlášení); [tenantId] slouží k validaci tenantu.
  static Future<void> _syncUserProfileCache(
    String tenantId,
    DriftSyncRepos driftRepos, {
    void Function(String)? onSyncError,
  }) async {
    final sessionUser = SupabaseService.client.auth.currentUser;
    final uid = sessionUser == null ? '' : sessionUser.id.trim();
    if (uid.isEmpty) return;
    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('tenant_id, name, first_name, last_name, email, role, updated_at')
          .eq('auth_id', uid)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (res == null) return;
      final map = Map<String, dynamic>.from(res as Map);
      await driftRepos.userProfile.upsertFromProfileMap(
        authUserId: uid,
        map: map,
        expectedTenantId: tenantId,
      );
    } catch (e, st) {
      onSyncError?.call('User profile cache sync: $e');
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerSyncService._syncUserProfileCache ERROR: $e');
        // ignore: avoid_print
        print(st);
      }
    }
  }

  /// Stáhne vlastní `staff_absences` přihlášeného pracovníka a uloží je do Driftu.
  ///
  /// PROČ: Seznam v „Moje nepřítomnost“ čte výhradně SQLite; tento krok dorovná stav se serverem po úkolech.
  /// Sloupce `created_at` / `updated_at` musí existovat v PostgreSQL – viz migrace
  /// `20260401100000_staff_absences_created_updated_at.sql` v repozitáři.
  static Future<void> _syncStaffAbsences(
    String tenantId,
    String workerId,
    DriftSyncRepos driftRepos, {
    void Function(String)? onSyncError,
  }) async {
    if (tenantId.isEmpty || workerId.isEmpty) return;
    try {
      final raw = await SupabaseService.safeFrom('staff_absences', tenantId)
          .select(
            'id, tenant_id, profile_id, invitation_id, start_date, end_date, reason, status, created_at, updated_at',
          )
          .eq('profile_id', workerId)
          .order('start_date', ascending: false);

      final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
      await driftRepos.staffAbsence.replaceFromSupabaseForProfile(tenantId, workerId, list);
    } catch (e, st) {
      // PROČ: Uživatel nesmí vidět PostgREST ani stack – jedna obecná věta; technické detaily jen v debug konzoli.
      onSyncError?.call('worker.sync.absences_sync_failed_generic_user_friendly'.tr());
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerSyncService._syncStaffAbsences ERROR: $e');
        // ignore: avoid_print
        print(st);
      }
    }
  }

  /// Stáhne `employee_cash_wallets` + transakce pro přihlášeného workera a uloží do Driftu.
  ///
  /// PROČ: Peněženka v aplikaci čte výhradně SQLite; měnu doplníme z již staženého záznamu tenanta v Driftu.
  static Future<void> _syncEmployeeCash(
    String tenantId,
    String workerId,
    DriftSyncRepos driftRepos, {
    void Function(String)? onSyncError,
  }) async {
    if (tenantId.isEmpty || workerId.isEmpty) return;
    try {
      final walletRaw = await SupabaseService.safeFrom('employee_cash_wallets', tenantId)
          .select('id, tenant_id, profile_id, balance, updated_at')
          .eq('profile_id', workerId)
          .maybeSingle();

      Map<String, dynamic>? walletMap;
      if (walletRaw != null) {
        walletMap = Map<String, dynamic>.from(walletRaw as Map);
      }

      var txList = <dynamic>[];
      final wid = walletMap?['id']?.toString().trim();
      if (wid != null && wid.isNotEmpty) {
        final txData = await SupabaseService.safeFrom('employee_cash_transactions', tenantId)
            .select(
              'id, tenant_id, wallet_id, task_id, amount, transaction_type, created_by, created_at, note, receipt_image_url, expected_amount, apartment_id, client_id, is_shortfall_resolved, shortfall_resolution_type, shortfall_resolution_note',
            )
            .eq('wallet_id', wid)
            .order('created_at', ascending: false)
            .limit(200);
        txList = txData is List ? List<dynamic>.from(txData) : <dynamic>[];
      }

      final tenantRow = await driftRepos.tenant.getBySupabaseId(tenantId);

      await driftRepos.employeeCash.replaceFromSupabaseForProfile(
        tenantId: tenantId,
        profileId: workerId,
        walletRow: walletMap,
        transactionRows: txList,
        currencyCode: tenantRow?.currency,
      );
    } catch (e, st) {
      onSyncError?.call('Employee cash sync: $e');
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerSyncService._syncEmployeeCash ERROR: $e');
        // ignore: avoid_print
        print(st);
      }
    }
  }

  /// Veřejné znovunačtení peněženky po online zápisu (dialog nemá spouštět celý task sync).
  static Future<void> pullEmployeeCashToDrift(
    String tenantId,
    String workerId,
    DriftSyncRepos driftRepos,
  ) async {
    await _syncEmployeeCash(tenantId, workerId, driftRepos, onSyncError: null);
  }

  static Future<void> _clearAndWrite(
    String tenantId,
    String workerId,
    List<dynamic> tasksList,
    List<dynamic> apartmentsData,
    List<dynamic> reservationsData,
    List<dynamic> clientsData,
    DriftSyncRepos driftRepos, {
    void Function(String)? onSyncError,
  }) async {
    await driftRepos.task.clearTasksForWorker(tenantId, workerId);
    // PROČ: Staré instance checklistů musí zmizet dřív, než zapíšeme nové úkoly (UUID se nemíchají).
    await driftRepos.taskChecklist.clearForTenant(tenantId);

    for (final a in apartmentsData) {
      final map = a is Map<String, dynamic> ? Map<String, dynamic>.from(a) : <String, dynamic>{};
      if (map.isEmpty) continue;
      await driftRepos.apartment.upsertFromSupabaseMap(map);
    }

    for (final r in reservationsData) {
      final map = r is Map<String, dynamic> ? Map<String, dynamic>.from(r) : <String, dynamic>{};
      if (map.isEmpty) continue;
      final supabaseId = map['id']?.toString().trim();
      if (supabaseId == null || supabaseId.isEmpty) continue;
      await driftRepos.reservation.upsertFromSupabaseMap(map);
    }

    for (final c in clientsData) {
      final map = c is Map<String, dynamic> ? Map<String, dynamic>.from(c) : <String, dynamic>{};
      if (map.isEmpty) continue;
      final supabaseId = map['id']?.toString().trim();
      if (supabaseId == null || supabaseId.isEmpty) continue;
      await driftRepos.client.upsertFromSupabaseMap(map);
    }

    for (final t in tasksList) {
      final map = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
      if (map.isEmpty) continue;
      await driftRepos.task.upsertTaskFromSupabaseMap(map);
    }

    await _syncTaskChecklistsFromSupabase(tenantId, tasksList, driftRepos, onSyncError: onSyncError);
  }

  /// PostgREST: hlavička `task_checklists` + vnořené `task_checklist_items` v jednom roundtripu.
  ///
  /// PROČ: Dříve stažené hlavičky bez položek (nebo chyba druhého dotazu) zanechávaly Drift bez řádků
  /// pro UI (`watchItemsForTask` joinuje obě tabulky). Embed zajistí konzistenci hlavička + položky.
  static const String _taskChecklistsSelectWithNestedItems =
      'id, tenant_id, task_id, template_id, created_at, updated_at, '
      'task_checklist_items('
      'id, tenant_id, task_checklist_id, title, is_photo_required, sort_order, '
      'is_completed, completed_at, completed_by, photo_url, created_at, updated_at'
      ')';

  /// Maximální počet UUID v jednom `.inFilter` – předejde příliš dlouhým URL / limitům PostgREST.
  static const int _syncInFilterChunkSize = 80;

  /// Stáhne instance checklistů a jejich položky pro úkoly worker rozhraní (RLS: přiřazený úkol).
  ///
  /// PROČ: Worker detail potřebuje lokální kopii pro offline odškrtávání; volá se po zápisu `tasks` do Driftu.
  /// [_clearAndWrite] předtím zavolal [DriftTaskChecklistRepository.clearForTenant] – „duchové“ z minulého
  /// sync se smažou celým tenantem; sem zapisujeme jen aktuální stav ze serveru.
  static Future<void> _syncTaskChecklistsFromSupabase(
    String tenantId,
    List<dynamic> tasksList,
    DriftSyncRepos driftRepos, {
    void Function(String)? onSyncError,
  }) async {
    if (tenantId.isEmpty) return;
    final taskIds = <String>[];
    for (final t in tasksList) {
      final m = t is Map<String, dynamic> ? Map<String, dynamic>.from(t) : <String, dynamic>{};
      final id = m['id']?.toString().trim();
      if (id != null && id.isNotEmpty) taskIds.add(id);
    }
    if (taskIds.isEmpty) return;
    try {
      for (var i = 0; i < taskIds.length; i += _syncInFilterChunkSize) {
        final end = i + _syncInFilterChunkSize > taskIds.length ? taskIds.length : i + _syncInFilterChunkSize;
        final chunk = taskIds.sublist(i, end);
        var usedNested = false;
        try {
          final nestedRaw = await SupabaseService.safeFrom('task_checklists', tenantId)
              .select(_taskChecklistsSelectWithNestedItems)
              .inFilter('task_id', chunk);
          final nestedList = nestedRaw is List ? List<dynamic>.from(nestedRaw) : <dynamic>[];
          for (final raw in nestedList) {
            final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
            if (map.isEmpty) continue;
            final nestedItems = map['task_checklist_items'];
            map.remove('task_checklist_items');
            await driftRepos.taskChecklist.upsertChecklistFromSupabaseMap(map);
            if (nestedItems is List) {
              for (final itemRaw in nestedItems) {
                final imap = itemRaw is Map<String, dynamic>
                    ? Map<String, dynamic>.from(itemRaw)
                    : Map<String, dynamic>.from(itemRaw as Map);
                if (imap.isEmpty) continue;
                await driftRepos.taskChecklist.upsertItemFromSupabaseMap(imap);
              }
            }
          }
          usedNested = true;
        } catch (e, st) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('WorkerSyncService: embed task_checklists selhal, zkouším dvoukrok: $e');
            // ignore: avoid_print
            print(st);
          }
        }
        if (!usedNested) {
          await _syncTaskChecklistsTwoStepForTaskChunk(tenantId, chunk, driftRepos);
        }
      }
    } catch (e, st) {
      onSyncError?.call('Checklist sync: $e');
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerSyncService._syncTaskChecklistsFromSupabase ERROR: $e');
        // ignore: avoid_print
        print(st);
      }
    }
  }

  /// Záložní stažení: nejdřív hlavičky pro [taskIdsChunk], pak položky po `task_checklist_id` (také po částech).
  ///
  /// PROČ: Pokud PostgREST embed neprojde (starší API, chyba parsování), stále dodáme data do Driftu.
  static Future<void> _syncTaskChecklistsTwoStepForTaskChunk(
    String tenantId,
    List<String> taskIdsChunk,
    DriftSyncRepos driftRepos,
  ) async {
    final headersRaw = await SupabaseService.safeFrom('task_checklists', tenantId)
        .select('id, tenant_id, task_id, template_id, created_at, updated_at')
        .inFilter('task_id', taskIdsChunk);
    final headersList = headersRaw is List ? List<dynamic>.from(headersRaw) : <dynamic>[];
    final checklistIds = <String>[];
    for (final raw in headersList) {
      final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (map.isEmpty) continue;
      await driftRepos.taskChecklist.upsertChecklistFromSupabaseMap(map);
      final cid = map['id']?.toString().trim();
      if (cid != null && cid.isNotEmpty) checklistIds.add(cid);
    }
    if (checklistIds.isEmpty) return;

    for (var j = 0; j < checklistIds.length; j += _syncInFilterChunkSize) {
      final jEnd = j + _syncInFilterChunkSize > checklistIds.length ? checklistIds.length : j + _syncInFilterChunkSize;
      final idChunk = checklistIds.sublist(j, jEnd);
      final itemsRaw = await SupabaseService.safeFrom('task_checklist_items', tenantId)
          .select(
            'id, tenant_id, task_checklist_id, title, is_photo_required, sort_order, is_completed, completed_at, completed_by, photo_url, created_at, updated_at',
          )
          .inFilter('task_checklist_id', idChunk);
      final itemsList = itemsRaw is List ? List<dynamic>.from(itemsRaw) : <dynamic>[];
      for (final raw in itemsList) {
        final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        if (map.isEmpty) continue;
        await driftRepos.taskChecklist.upsertItemFromSupabaseMap(map);
      }
    }
  }

  /// Push pending úkolů na Supabase s Timestamp Merging (Smart Merge).
  ///
  /// PROČ TIMESTAMP MERGING: Bez něj by platilo "Last-write-wins" – mobilní aplikace
  /// by po připojení přepsala změny, které mezitím udělal administrátor na webu.
  /// Timestamp Merging před odesláním lokální mutace:
  /// 1) Stáhne aktuální verzi úkolu ze serveru (updated_at, status, description, metadata, …).
  /// 2) Pokud je server.updated_at novější než lokální last_synced_at → konflikt.
  /// 3) Při konfliktu aplikuje byznysová pravidla (Smart Merge), odešle sloučený stav
  ///    na Supabase a zapíše ho i do lokální Drift DB.
  ///
  /// BYZNYSOVÁ PRAVIDLA (PROČ takto):
  /// - PRAVIDLO 1 (Status): Lokální změna statusu pracovníkem má přednost – pracovník byl
  ///   na místě a práci dokončil; přepisovat jeho "completed" administrátorskou úpravou
  ///   by bylo chybné.
  /// - PRAVIDLO 2 (Poznámky): Pokud se změnily poznámky na serveru i lokálně, texty se
  ///   nesmí přepsat, ale spojí se (append): "[Admin]: text ze serveru \n [Worker]: lokální text",
  ///   aby se neztratila ani administrátorská ani terénní informace.
  /// - PRAVIDLO 3 (Ostatní): U dat, která pracovník typicky nemění (termín úkolu, cena,
  ///   název, typ úkolu), má vždy přednost novější verze ze serveru – zdroj pravdy je admin.
  static Future<void> pushPendingUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
    DriftSyncRepos? driftRepos,
    void Function()? onSmartMergeApplied,
  }) async {
    debugPrint('🔄 SYNC: Spouštím pushPendingUpdates...');
    if (tenantId.isEmpty) return;

    await pushPendingReservationUpdates(tenantId, onSyncError: onSyncError, driftRepos: driftRepos);

    if (driftRepos == null) return;

    final pending = await driftRepos.task.getPendingTasks(tenantId);
    if (pending.isEmpty) return;

    for (final task in pending) {
      final supabaseId = task.supabaseId;
      if (supabaseId == null || supabaseId.isEmpty) continue;

      debugPrint('🔄 SYNC: Pokus o odeslání úkolu s ID: $supabaseId, nový status: ${task.status}');
      try {
        // ---------- KROK 1: Před odesláním stáhnout aktuální verzi úkolu ze serveru ----------
        // PROČ: Abychom mohli detekovat konflikt (admin mezitím upravil úkol) a aplikovat Smart Merge.
        final serverRow = await _fetchCurrentTaskFromServer(supabaseId, tenantId);

        // ---------- KROK 2: Detekce konfliktu a sestavení sloučeného payloadu ----------
        final serverUpdatedAt = serverRow != null ? _parseServerUpdatedAt(serverRow) : null;
        final lastSynced = task.lastSyncedAt;
        final hasConflict = serverUpdatedAt != null &&
            (lastSynced == null || serverUpdatedAt.isAfter(lastSynced));

        final Map<String, dynamic> updates;
        String mergedStatus = task.status;
        String? mergedDescription;
        String? mergedMetadataJson;
        String? serverTitle;
        String? serverTaskType;
        DateTime? serverScheduledStart;

        if (hasConflict && serverRow != null) {
          // Smart Merge: aplikace byznysových pravidel.
          mergedStatus = task.status; // PRAVIDLO 1: status má vždy lokální (worker).
          mergedDescription = _mergeNotes(
            serverNotes: serverRow['description']?.toString().trim(),
            localNotes: task.description.trim(),
          );
          final serverMeta = _parseMetadataFromDynamic(serverRow['metadata']);
          final localMeta = _parseMetadataForSync(task.metadataJson ?? '{}');
          final mergedMeta = _mergeMetadataMap(serverMeta ?? {}, localMeta);
          mergedMetadataJson = mergedMeta.isEmpty ? null : jsonEncode(mergedMeta);

          serverTitle = serverRow['title']?.toString().trim();
          serverTaskType = serverRow['task_type']?.toString().trim();
          final ss = serverRow['scheduled_start'];
          if (ss != null) serverScheduledStart = DateTime.tryParse(ss.toString())?.toUtc();

          updates = <String, dynamic>{
            'status': mergedStatus,
            'description': mergedDescription,
          };
          if (serverTitle != null && serverTitle.isNotEmpty) updates['title'] = serverTitle;
          if (serverTaskType != null && serverTaskType.isNotEmpty) updates['task_type'] = serverTaskType;
          if (serverScheduledStart != null) {
            updates['scheduled_start'] = serverScheduledStart.toIso8601String();
          }
          if (mergedMeta.isNotEmpty) updates['metadata'] = mergedMeta;
        } else {
          // Žádný konflikt: odesíláme jen lokální změny (status, časy, metadata).
          updates = <String, dynamic>{'status': task.status};
          mergedDescription = task.description;
          mergedMetadataJson = task.metadataJson;
        }

        if (task.startedAt != null) {
          updates['started_at'] = task.startedAt!.toUtc().toIso8601String();
        }
        if (task.completedAt != null) {
          updates['completed_at'] = task.completedAt!.toUtc().toIso8601String();
        }
        if (!hasConflict &&
            task.metadataJson != null &&
            task.metadataJson!.trim().isNotEmpty) {
          try {
            final parsed = _parseMetadataForSync(task.metadataJson!);
            if (parsed != null && parsed.isNotEmpty) updates['metadata'] = parsed;
          } catch (e, st) {
            AppLogger.error('WorkerSyncService: parsování metadataJson při pushPendingUpdates selhalo', e, st);
          }
        }

        await SupabaseService.safeFrom('tasks', tenantId).update(updates).eq('id', supabaseId);
        debugPrint('✅ SYNC ÚSPĚCH: Úkol $supabaseId byl odeslán.');

        if (hasConflict) {
          await driftRepos.task.applyMergedTaskAndMarkSynced(
            task,
            mergedStatus: mergedStatus,
            mergedDescription: mergedDescription,
            mergedMetadataJson: mergedMetadataJson,
            title: serverTitle,
            taskType: serverTaskType,
            scheduledStart: serverScheduledStart,
          );
          onSmartMergeApplied?.call();
        } else {
          await driftRepos.task.markTaskSynced(task);
        }
      } catch (e) {
        onSyncError?.call(e.toString());
        debugPrint('❌ SYNC CHYBA (Supabase): $e');
        if (kDebugMode) {
          // ignore: avoid_print
          print('WorkerSyncService.pushPendingUpdates: update failed for $supabaseId: $e');
        }
        continue;
      }
    }
  }

  /// Stáhne aktuální řádek úkolu ze Supabase (pro Timestamp Merging).
  static Future<Map<String, dynamic>?> _fetchCurrentTaskFromServer(String taskId, String tenantId) async {
    try {
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select('id, updated_at, status, description, metadata, scheduled_start, title, task_type')
          .eq('id', taskId)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e, st) {
      AppLogger.error('WorkerSyncService: načtení řádku úkolu ze Supabase (_fetchCurrentTaskFromServer) selhalo', e, st);
      return null;
    }
  }

  static DateTime? _parseServerUpdatedAt(Map<String, dynamic> serverRow) {
    final v = serverRow['updated_at'];
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    final parsed = DateTime.tryParse(v.toString());
    return parsed?.toUtc();
  }

  /// Sloučí poznámky při konfliktu: "[Admin]: text ze serveru \n [Worker]: lokální text".
  static String _mergeNotes({String? serverNotes, String? localNotes}) {
    final server = (serverNotes ?? '').trim();
    final local = (localNotes ?? '').trim();
    if (server.isEmpty) return local;
    if (local.isEmpty) return server;
    return '[Admin]: $server\n[Worker]: $local';
  }

  static Map<String, dynamic>? _parseMetadataFromDynamic(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      AppLogger.error('WorkerSyncService: jsonDecode metadat v _parseMetadataFromDynamic selhal', e, st);
    }
    return null;
  }

  /// Sloučí metadata: klíče ze serveru + klíče z lokálu (lokální přepíše při duplicitě).
  static Map<String, dynamic> _mergeMetadataMap(Map<String, dynamic> server, Map<String, dynamic>? local) {
    final out = Map<String, dynamic>.from(server);
    if (local != null && local.isNotEmpty) {
      for (final e in local.entries) {
        out[e.key] = e.value;
      }
    }
    return out;
  }


  /// Stejný výběr sloupců jako při stažení rezervací do Driftu + [updated_at] pro Timestamp Merging.
  static const String _reservationPushSelectColumns =
      'id, tenant_id, updated_at, status, guest_name, guest_phone, reference_number, '
      'special_requests, guest_language, start_date, end_date';

  /// Odešle pending změny rezervací (typicky status z check-inu v terénu) s Timestamp Merging.
  ///
  /// PROČ STEJNÝ MODEL JAKO ÚKOLY ([pushPendingUpdates]): Bez porovnání [updated_at] by hrozilo
  /// „last-write-wins“ v lokální DB – worker by po syncu dál viděl zastaralé údaje, i když
  /// Postgres jsme nechali správně (UPDATE jen `status`). Smart merge:
  /// 1) Stáhnout aktuální řádek ze Supabase.
  /// 2) Porovnat `server.updated_at` s lokálním [Reservation.lastSyncedAt] → detekce konfliktu.
  /// 3) Na server vždy poslat jen `status` z terénu (worker jiná pole v Driftu nemění).
  /// 4) Po úspěchu přepsat Drift snapshotem ze serveru + status z pracovníka ([applyReservationAfterStatusPush]).
  ///
  /// Při chybě jedné položky smyčka pokračuje (try-catch + continue).
  static Future<void> pushPendingReservationUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
    DriftSyncRepos? driftRepos,
  }) async {
    if (tenantId.isEmpty) return;
    if (driftRepos == null) return;

    final pending = await driftRepos.reservation.getPendingReservations(tenantId);

    for (final res in pending) {
      final supabaseId = res.supabaseId;
      if (supabaseId == null || supabaseId.isEmpty) continue;

      debugPrint('🔄 SYNC: Rezervace $supabaseId → status: ${res.status}');
      try {
        final serverRow = await _fetchCurrentReservationFromServer(supabaseId, tenantId);
        if (serverRow == null) {
          // PROČ: Řádek na serveru neexistuje nebo je mimo RLS / soft-delete – pending push nemá cíl.
          await driftRepos.reservation.deleteLocalReservationByDriftId(res.id);
          continue;
        }

        final serverUpdatedAt = _parseServerUpdatedAt(serverRow);
        final lastSynced = res.lastSyncedAt;
        final hasConflict = serverUpdatedAt != null &&
            (lastSynced == null || serverUpdatedAt.isAfter(lastSynced));

        if (hasConflict) {
          // Timestamp merging pro rezervace: serverová verze je novější než stav, se kterým worker pracoval offline.
          // Přesto na Supabase aplikujeme lokální status z terénu (check-in/check-out), aby se neztratila práce v terénu;
          // ostatní sloupce zůstávají na serveru beze změny (UPDATE posíláme jen status). Drift po úspěchu sloučí
          // zobrazení: aktuální data ze snapshotu + status z pracovníka — adminovy poznámky / termíny nepřepisujeme starými lokálními kopiemi.
          if (kDebugMode) {
            debugPrint(
              '🔀 SYNC MERGE rezervace $supabaseId: server updated_at novější než lastSyncedAt — Drift se po pushi zarovná se serverem.',
            );
          }
        }

        await SupabaseService.safeFrom('reservations', tenantId)
            .update({'status': res.status})
            .eq('id', supabaseId);
        debugPrint('✅ SYNC ÚSPĚCH: Rezervace $supabaseId byla odeslána.');

        await driftRepos.reservation.applyReservationAfterStatusPush(
          localDriftId: res.id,
          serverSnapshot: serverRow,
          statusFromWorker: res.status,
        );
      } catch (e) {
        onSyncError?.call(e.toString());
        debugPrint('❌ SYNC CHYBA (Rezervace): $e');
        if (kDebugMode) {
          // ignore: avoid_print
          print('WorkerSyncService.pushPendingReservationUpdates: $supabaseId: $e');
        }
        continue;
      }
    }
  }

  /// Aktuální řádek rezervace ze Supabase (Timestamp Merging před push UPDATE).
  ///
  /// PROČ: Nevyžírá výjimky – při síťové chybě nechá volajícího catch v [pushPendingReservationUpdates],
  /// aby se pending záznam nesmazal omylem (null by vypadalo jako „není na serveru“).
  static Future<Map<String, dynamic>?> _fetchCurrentReservationFromServer(
    String reservationId,
    String tenantId,
  ) async {
    final raw = await SupabaseService.safeFrom('reservations', tenantId)
        .select(_reservationPushSelectColumns)
        .eq('id', reservationId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  static Future<int> getPendingSyncCount(String tenantId, {DriftSyncRepos? driftRepos}) async {
    if (tenantId.isEmpty) return 0;
    if (driftRepos == null) return 0;

    final pendingTasks = await driftRepos.task.getPendingTasks(tenantId);
    final pendingRes = await driftRepos.reservation.getPendingReservations(tenantId);
    return pendingTasks.length + pendingRes.length;
  }

  static Map<String, dynamic>? _parseMetadataForSync(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      AppLogger.error('WorkerSyncService: jsonDecode v _parseMetadataForSync selhal', e, st);
    }
    return null;
  }
}
