import 'package:falconest/core/services/supabase_service.dart';

/// Jeden záznam z tabulky [agency_management_settlements] – schválená provize pro Lovec/Farmáře.
///
/// PROČ: Provize se zadávají ručně na základě výkazů práce, aby Super-Admin mohl zohlednit
/// reálný přínos a zabránilo se podvodům. Žádná plná automatizace – vždy schválení člověkem.
class AgencySettlementRow {
  const AgencySettlementRow({
    required this.id,
    required this.profileId,
    required this.tenantId,
    required this.settlementPeriod,
    required this.roleType,
    required this.amount,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.profileName,
  });

  final String id;
  final String profileId;
  final String tenantId;
  /// První den měsíce vyúčtování (např. 2026-03-01).
  final DateTime settlementPeriod;
  /// 'hunter' = Lovec, 'farmer' = Farmář.
  final String roleType;
  final num amount;
  /// pending | approved | paid
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profileName;

  bool get isApproved => status == 'approved' || status == 'paid';
}

/// Repozitář pro tabulku [agency_management_settlements].
///
/// PROČ: Super-Admin na konci měsíce ručně zadá a schválí provizi pro Lovce a Farmáře.
/// UNIQUE (profile_id, tenant_id, settlement_period, role_type) – upsert při opakovaném schválení.
class AgencyManagementSettlementsRepository {
  AgencyManagementSettlementsRepository();

  /// Formátuje první den měsíce pro DB (yyyy-MM-dd).
  static String _periodToDateStr(DateTime period) {
    final y = period.year;
    final m = period.month.toString().padLeft(2, '0');
    final d = period.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Načte schválené (a ostatní) provize za daný měsíc. [period] = první den měsíce.
  Future<List<AgencySettlementRow>> getSettlementsForPeriod(DateTime period) async {
    final periodStr = _periodToDateStr(period);
    final res = await SupabaseService.client
        .from('agency_management_settlements')
        .select(
          'id, profile_id, tenant_id, settlement_period, role_type, amount, status, '
          'approved_by, approved_at, created_at, updated_at, profiles(name)',
        )
        .eq('settlement_period', periodStr)
        .order('tenant_id', ascending: true);
    final list = res as List<dynamic>;
    final result = <AgencySettlementRow>[];
    for (final e in list) {
      try {
        result.add(_parseRow(Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    return result;
  }

  /// Vloží nebo aktualizuje provizi (UNIQUE na profile_id, tenant_id, settlement_period, role_type).
  /// Nastaví status approved a approved_by / approved_at. [approvedByProfileId] = profil Super-Admina, který schvaluje.
  Future<void> upsertSettlement({
    required String profileId,
    required String tenantId,
    required DateTime settlementPeriod,
    required String roleType,
    required num amount,
    required String approvedByProfileId,
  }) async {
    if (profileId.isEmpty || tenantId.isEmpty) throw ArgumentError('profileId a tenantId musí být neprázdné');
    if (roleType != 'hunter' && roleType != 'farmer') throw ArgumentError('roleType musí být hunter nebo farmer');
    if (amount < 0) throw ArgumentError('amount nesmí být záporné');

    final periodStr = _periodToDateStr(settlementPeriod);
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'profile_id': profileId,
      'tenant_id': tenantId,
      'settlement_period': periodStr,
      'role_type': roleType,
      'amount': amount.toDouble(),
      'status': 'approved',
      'approved_by': approvedByProfileId,
      'approved_at': now,
      'updated_at': now,
    };
    await SupabaseService.client.from('agency_management_settlements').upsert(
      payload,
      onConflict: 'profile_id,tenant_id,settlement_period,role_type',
    );
  }

  static AgencySettlementRow _parseRow(Map<String, dynamic> m) {
    String? profileName;
    try {
      final p = m['profiles'];
      if (p is Map) profileName = (p['name'] as String?)?.trim();
    } catch (_) {}
    final periodRaw = m['settlement_period'];
    DateTime period = DateTime.now();
    if (periodRaw != null) {
      if (periodRaw is String) period = DateTime.tryParse(periodRaw) ?? period;
      if (periodRaw is DateTime) period = periodRaw;
    }
    return AgencySettlementRow(
      id: (m['id'] as String?) ?? '',
      profileId: (m['profile_id'] as String?) ?? '',
      tenantId: (m['tenant_id'] as String?) ?? '',
      settlementPeriod: period,
      roleType: (m['role_type'] as String?) ?? 'farmer',
      amount: (m['amount'] as num?) ?? 0,
      status: (m['status'] as String?) ?? 'pending',
      approvedBy: (m['approved_by'] as String?)?.trim(),
      approvedAt: _parseDateTime(m['approved_at']),
      createdAt: _parseDateTime(m['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDateTime(m['updated_at']) ?? DateTime.now().toUtc(),
      profileName: profileName,
    );
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
