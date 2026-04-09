import 'package:easy_localization/easy_localization.dart';
import 'dart:async';

import 'package:drift/drift.dart';

import 'package:falconest_drift/app_database.dart' as drift_db;

/// Jedna řádka pro sestavení Worker UI výdělků (výplata nebo provize) po JOIN s úkolem.
///
/// PROČ: Repozitář neimportuje feature moduly – provider mapuje na [WorkerEarningsRow].
class DriftWorkerEarningsLineDto {
  const DriftWorkerEarningsLineDto({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.completedAt,
    required this.amount,
    required this.status,
    required this.isCommission,
  });

  final String id;
  final String taskId;
  final String taskTitle;
  final DateTime? completedAt;
  final double amount;
  final String status;
  final bool isCommission;
}

/// Souhrn výdělků z lokální SQLite – stejná sémantika jako dříve ze Supabase.
class DriftWorkerEarningsSnapshot {
  const DriftWorkerEarningsSnapshot({
    required this.pendingTotal,
    required this.paidTotal,
    required this.rows,
  });

  final double pendingTotal;
  final double paidTotal;
  final List<DriftWorkerEarningsLineDto> rows;

  static const DriftWorkerEarningsSnapshot empty = DriftWorkerEarningsSnapshot(
    pendingTotal: 0,
    paidTotal: 0,
    rows: [],
  );
}

/// Lokální čtení a sync cache `task_payouts` / `task_commissions` pro přihlášeného pracovníka.
///
/// PROČ: Obrazovka „Moje výdělky“ musí fungovat offline; data přijdou jen při worker sync z Supabase,
/// nikoli při každém otevření obrazovky.
class DriftTaskPayoutRepository {
  DriftTaskPayoutRepository(this._db);

  final drift_db.AppDatabase _db;

  /// Název úkolu pro řádek výplaty – shodná priorita jako server (custom_title → title).
  static String _taskDisplayTitle(drift_db.Task? t) {
    if (t == null) return 'common.placeholder_dash'.tr();
    final c = t.customTitle?.trim() ?? '';
    if (c.isNotEmpty) return c;
    final title = t.title.trim();
    return title.isEmpty ? 'common.placeholder_dash'.tr() : title;
  }

  /// Přepíše lokální výplaty a provize pro daného pracovníka podle odpovědi API (full replace).
  ///
  /// PROČ: Jednoduchá konzistence s RLS dotazem `.eq('profile_id', workerId)` – nemusíme řešit
  /// mazání jednotlivých UUID při změně na serveru.
  Future<void> replaceFromSupabaseForProfile(
    String tenantId,
    String profileId,
    List<dynamic> payoutsRaw,
    List<dynamic> commissionsRaw,
  ) async {
    if (tenantId.isEmpty || profileId.isEmpty) return;

    await (_db.delete(_db.taskPayouts)
          ..where((p) => p.tenantId.equals(tenantId) & p.profileId.equals(profileId)))
        .go();
    await (_db.delete(_db.taskCommissions)
          ..where((c) => c.tenantId.equals(tenantId) & c.profileId.equals(profileId)))
        .go();

    for (final raw in payoutsRaw) {
      final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final sid = map['id']?.toString().trim();
      if (sid == null || sid.isEmpty) continue;
      final taskId = map['task_id']?.toString().trim();
      if (taskId == null || taskId.isEmpty) continue;
      final pid = map['profile_id']?.toString().trim();
      if (pid == null || pid.isEmpty) continue;

      final amount = _parseAmount(map['amount']);
      final status = (map['status']?.toString() ?? 'pending').trim();
      final createdAt = _parseDate(map['created_at']) ?? DateTime.now().toUtc();
      final updatedAt = _parseDate(map['updated_at']) ?? createdAt;

      await _db.into(_db.taskPayouts).insert(
            drift_db.TaskPayoutsCompanion.insert(
              supabaseId: sid,
              tenantId: tenantId,
              taskId: taskId,
              profileId: pid,
              amount: amount,
              status: Value(status.isEmpty ? 'pending' : status),
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );
    }

    for (final raw in commissionsRaw) {
      final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final sid = map['id']?.toString().trim();
      if (sid == null || sid.isEmpty) continue;
      final taskId = map['task_id']?.toString().trim();
      if (taskId == null || taskId.isEmpty) continue;
      final pid = map['profile_id']?.toString().trim();

      final amount = _parseAmount(map['amount']);
      final status = (map['status']?.toString() ?? 'pending').trim();
      final createdAt = _parseDate(map['created_at']) ?? DateTime.now().toUtc();
      final updatedAt = _parseDate(map['updated_at']) ?? createdAt;
      final clientId = map['client_id']?.toString().trim();

      await _db.into(_db.taskCommissions).insert(
            drift_db.TaskCommissionsCompanion.insert(
              supabaseId: sid,
              tenantId: tenantId,
              taskId: taskId,
              profileId: Value(pid),
              clientId: Value((clientId != null && clientId.isNotEmpty) ? clientId : null),
              amount: amount,
              status: Value(status.isEmpty ? 'pending' : status),
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );
    }
  }

  static double _parseAmount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc();
  }

  /// Sleduje výplaty + provize a JOIN na `tasks` pro název a `completed_at`.
  ///
  /// PROČ: Dva zdrojové streamy slučujeme přes [Stream.multi], aby se UI překreslilo při změně
  /// kterékoli tabulky nebo při aktualizaci názvu úkolu (join na tasks).
  Stream<DriftWorkerEarningsSnapshot> watchEarningsForProfile(String tenantId, String profileId) {
    if (tenantId.isEmpty || profileId.isEmpty) {
      return Stream.value(DriftWorkerEarningsSnapshot.empty);
    }

    final payoutJoin = _db.select(_db.taskPayouts).join([
      leftOuterJoin(
        _db.tasks,
        _db.tasks.supabaseId.equalsExp(_db.taskPayouts.taskId) &
            _db.tasks.tenantId.equalsExp(_db.taskPayouts.tenantId),
      ),
    ])
      ..where(_db.taskPayouts.tenantId.equals(tenantId) & _db.taskPayouts.profileId.equals(profileId));

    final commissionJoin = _db.select(_db.taskCommissions).join([
      leftOuterJoin(
        _db.tasks,
        _db.tasks.supabaseId.equalsExp(_db.taskCommissions.taskId) &
            _db.tasks.tenantId.equalsExp(_db.taskCommissions.tenantId),
      ),
    ])
      ..where(
        _db.taskCommissions.tenantId.equals(tenantId) &
            _db.taskCommissions.profileId.equals(profileId),
      );

    return Stream<DriftWorkerEarningsSnapshot>.multi((multiController) {
      Future<void> emit() async {
        if (multiController.isClosed) return;
        try {
          multiController.add(await _buildSnapshot(tenantId, profileId));
        } catch (e, st) {
          multiController.addError(e, st);
        }
      }

      late final StreamSubscription sub1;
      late final StreamSubscription sub2;
      sub1 = payoutJoin.watch().listen((_) => emit());
      sub2 = commissionJoin.watch().listen((_) => emit());
      multiController.onCancel = () {
        sub1.cancel();
        sub2.cancel();
      };
      emit();
    });
  }

  Future<DriftWorkerEarningsSnapshot> _buildSnapshot(String tenantId, String profileId) async {
    final payoutRows = await (_db.select(_db.taskPayouts).join([
      leftOuterJoin(
        _db.tasks,
        _db.tasks.supabaseId.equalsExp(_db.taskPayouts.taskId) &
            _db.tasks.tenantId.equalsExp(_db.taskPayouts.tenantId),
      ),
    ])
          ..where(_db.taskPayouts.tenantId.equals(tenantId) & _db.taskPayouts.profileId.equals(profileId)))
        .get();

    final commissionRows = await (_db.select(_db.taskCommissions).join([
      leftOuterJoin(
        _db.tasks,
        _db.tasks.supabaseId.equalsExp(_db.taskCommissions.taskId) &
            _db.tasks.tenantId.equalsExp(_db.taskCommissions.tenantId),
      ),
    ])
          ..where(
            _db.taskCommissions.tenantId.equals(tenantId) &
                _db.taskCommissions.profileId.equals(profileId),
          ))
        .get();

    final lines = <DriftWorkerEarningsLineDto>[];
    double pendingTotal = 0;
    double paidTotal = 0;

    for (final r in payoutRows) {
      final p = r.readTable(_db.taskPayouts);
      final task = r.readTableOrNull(_db.tasks);
      final st = p.status.trim().toLowerCase();
      if (st == 'paid') {
        paidTotal += p.amount;
      } else {
        pendingTotal += p.amount;
      }
      lines.add(
        DriftWorkerEarningsLineDto(
          id: p.supabaseId,
          taskId: p.taskId,
          taskTitle: _taskDisplayTitle(task),
          completedAt: task?.completedAt,
          amount: p.amount,
          status: st,
          isCommission: false,
        ),
      );
    }

    for (final r in commissionRows) {
      final c = r.readTable(_db.taskCommissions);
      final task = r.readTableOrNull(_db.tasks);
      final st = c.status.trim().toLowerCase();
      if (st == 'paid') {
        paidTotal += c.amount;
      } else {
        pendingTotal += c.amount;
      }
      lines.add(
        DriftWorkerEarningsLineDto(
          id: c.supabaseId,
          taskId: c.taskId,
          taskTitle: _taskDisplayTitle(task),
          completedAt: task?.completedAt,
          amount: c.amount,
          status: st,
          isCommission: true,
        ),
      );
    }

    lines.sort((a, b) {
      final da = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db_ = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db_.compareTo(da);
    });

    return DriftWorkerEarningsSnapshot(
      pendingTotal: pendingTotal,
      paidTotal: paidTotal,
      rows: lines,
    );
  }
}
