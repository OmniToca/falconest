import 'package:falconest/core/services/supabase_service.dart';

/// Jeden záznam z tabulky [hq_staff_contracts] – smluvní parametry a odměny pro člena HQ.
///
/// PROČ: Oddělený model od DB řádku umožňuje jednotné zobrazení v UI (Profil, Smlouva a odměny)
/// a výpočty bez závislosti na názvech sloupců. Nullable číselné sloupce = podle typu pozice
/// se vyplní jen relevantní (např. účetní nemá commission_percent_managed).
class HqStaffContractRow {
  const HqStaffContractRow({
    required this.id,
    required this.profileId,
    required this.employmentType,
    this.positionLabel,
    this.fixedSalaryMonthly,
    this.bonusPerAcquiredAgency,
    this.commissionPercentManaged,
    required this.validFrom,
    this.validTo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String profileId;
  /// 'hpp' | 'ico'
  final String employmentType;
  final String? positionLabel;
  final num? fixedSalaryMonthly;
  final num? bonusPerAcquiredAgency;
  final num? commissionPercentManaged;
  final DateTime validFrom;
  final DateTime? validTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Smlouva je aktuálně platná (dnes v rozsahu valid_from .. valid_to).
  bool get isActive {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    if (validFrom.isAfter(today)) return false;
    if (validTo != null && validTo!.isBefore(today)) return false;
    return true;
  }
}

/// Repozitář pro tabulku [hq_staff_contracts].
///
/// PROČ: Clean Architecture – veškerý přístup k DB pro smlouvy HQ jde přes tento repozitář,
/// aby UI a providery nezávisely na Supabase a šlo snadno měnit zdroj dat nebo testovat.
class HqStaffContractRepository {
  HqStaffContractRepository();

  /// Načte aktuálně platnou smlouvu pro daný profil.
  /// Platná = valid_from <= dnes AND (valid_to IS NULL OR valid_to >= dnes). Načteme smlouvy
  /// s valid_from <= dnes, seřadíme valid_from DESC a v Dartu vybereme první s platným valid_to.
  Future<HqStaffContractRow?> getActiveContractForProfile(String profileId) async {
    if (profileId.trim().isEmpty) return null;
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final todayStr = _dateToStr(today);
    final res = await SupabaseService.client
        .from('hq_staff_contracts')
        .select('id, profile_id, employment_type, position_label, fixed_salary_monthly, bonus_per_acquired_agency, commission_percent_managed, valid_from, valid_to, created_at, updated_at')
        .eq('profile_id', profileId)
        .lte('valid_from', todayStr)
        .order('valid_from', ascending: false)
        .limit(10);
    final list = res as List<dynamic>;
    for (final e in list) {
      final row = _parseRow(Map<String, dynamic>.from(e as Map));
      if (row.validTo == null || !row.validTo!.isBefore(today)) return row;
    }
    return null;
  }

  /// Vytvoří novou smlouvu. [validFrom] výchozí dnes; [validTo] volitelné (otevřená smlouva).
  Future<HqStaffContractRow> createContract({
    required String profileId,
    required String employmentType,
    String? positionLabel,
    num? fixedSalaryMonthly,
    num? bonusPerAcquiredAgency,
    num? commissionPercentManaged,
    DateTime? validFrom,
    DateTime? validTo,
  }) async {
    if (profileId.trim().isEmpty) throw ArgumentError('profileId musí být neprázdný');
    if (employmentType != 'hpp' && employmentType != 'ico') {
      throw ArgumentError('employmentType musí být hpp nebo ico');
    }
    final from = validFrom ?? DateTime.now().toUtc();
    final fromStr = _dateToStr(from);
    final toStr = validTo != null ? _dateToStr(validTo) : null;
    final payload = <String, dynamic>{
      'profile_id': profileId,
      'employment_type': employmentType,
      'valid_from': fromStr,
      if (positionLabel != null && positionLabel.isNotEmpty) 'position_label': positionLabel,
      if (fixedSalaryMonthly != null && fixedSalaryMonthly >= 0) 'fixed_salary_monthly': fixedSalaryMonthly.toDouble(),
      if (bonusPerAcquiredAgency != null && bonusPerAcquiredAgency >= 0) 'bonus_per_acquired_agency': bonusPerAcquiredAgency.toDouble(),
      if (commissionPercentManaged != null && commissionPercentManaged >= 0 && commissionPercentManaged <= 100) 'commission_percent_managed': commissionPercentManaged.toDouble(),
      if (toStr != null) 'valid_to': toStr,
    };
    final res = await SupabaseService.client
        .from('hq_staff_contracts')
        .insert(payload)
        .select('id, profile_id, employment_type, position_label, fixed_salary_monthly, bonus_per_acquired_agency, commission_percent_managed, valid_from, valid_to, created_at, updated_at')
        .single();
    return _parseRow(Map<String, dynamic>.from(res as Map));
  }

  /// Ukončí smlouvu nastavením [validTo] na zadané datum (včetně).
  /// PROČ: Místo mazání zachováme historii; nová smlouva se vytvoří zvlášť s novým valid_from.
  Future<void> endContract(String contractId, DateTime validTo) async {
    if (contractId.trim().isEmpty) throw ArgumentError('contractId musí být neprázdný');
    final toStr = _dateToStr(validTo);
    await SupabaseService.client
        .from('hq_staff_contracts')
        .update({'valid_to': toStr, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', contractId);
  }

  static String _dateToStr(DateTime d) {
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static HqStaffContractRow _parseRow(Map<String, dynamic> m) {
    return HqStaffContractRow(
      id: (m['id'] as String?) ?? '',
      profileId: (m['profile_id'] as String?) ?? '',
      employmentType: (m['employment_type'] as String?) ?? 'hpp',
      positionLabel: (m['position_label'] as String?)?.trim(),
      fixedSalaryMonthly: m['fixed_salary_monthly'] as num?,
      bonusPerAcquiredAgency: m['bonus_per_acquired_agency'] as num?,
      commissionPercentManaged: m['commission_percent_managed'] as num?,
      validFrom: _parseDate(m['valid_from']) ?? DateTime.now().toUtc(),
      validTo: _parseDate(m['valid_to']),
      createdAt: _parseDateTime(m['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDateTime(m['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
