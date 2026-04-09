import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';

/// KPI souhrn „Absence radar do budoucna“ pro Admin Dashboard.
///
/// PROČ: Manažer potřebuje dopředu vidět, kdy bude v týmu nedostatek
/// personálu (schválené nepřítomnosti). To snižuje riziko, že budou
/// úkoly při plánování/dispatchi přiděleny někomu, kdo reálně nebude
/// dostupný.
class UpcomingAbsencesSummary {
  const UpcomingAbsencesSummary({
    required this.approvedAbsencesCount7Days,
    required this.approvedAbsencesCount14Days,
    required this.absentMemberProfileIds14Days,
  });

  /// Počet záznamů v `staff_absences`, které se vyskytují v intervalu
  /// „příštích 7 dní“ (včetně dneška).
  final int approvedAbsencesCount7Days;

  /// Počet záznamů v `staff_absences`, které se vyskytují v intervalu
  /// „příštích 14 dní“ (včetně dneška).
  final int approvedAbsencesCount14Days;

  /// Distinct seznam `profile_id` členů týmu, kteří budou v nepřítomnosti
  /// v horizontu 14 dní.
  ///
  /// PROČ: UI může zobrazit „kdo“ chybí, nejen „kolik“.
  final List<String> absentMemberProfileIds14Days;
}

/// Riverpod provider pro výpočet „Absence radar do budoucna“.
///
/// Poznámka k multi-tenantu:
/// - dotaz na `staff_absences` provádí už existující `staffAbsencesProvider`
///   (který už používá `SupabaseService.safeFrom` a filtruje podle tenantu).
/// - my pouze filtrujeme výsledky v paměti na období a na `profile_id`.
final upcomingAbsencesProvider =
    AsyncNotifierProvider<UpcomingAbsencesNotifier, UpcomingAbsencesSummary>(
  UpcomingAbsencesNotifier.new,
);

class UpcomingAbsencesNotifier
    extends AsyncNotifier<UpcomingAbsencesSummary> {
  static const int _horizonDays14 = 14;
  static const int _horizonDays7 = 7;

  DateTime _utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  bool _overlapsDayRange({
    required DateTime absStart,
    required DateTime absEnd,
    required DateTime windowStart,
    required DateTime windowEndInclusive,
  }) {
    // Inkluzivní intervaly (včetně dne start/end).
    final aStart = _utcDay(absStart);
    final aEnd = _utcDay(absEnd);
    return !aEnd.isBefore(windowStart) && !aStart.isAfter(windowEndInclusive);
  }

  @override
  Future<UpcomingAbsencesSummary> build() async {
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      return const UpcomingAbsencesSummary(
        approvedAbsencesCount7Days: 0,
        approvedAbsencesCount14Days: 0,
        absentMemberProfileIds14Days: [],
      );
    }

    try {
      // PROČ: `staffAbsencesProvider` už zajišťuje tenantové filtrování přes RLS
      // (a safeFrom) a parsuje datumy do typu `DateTime`.
      final absences = await ref.watch(staffAbsencesProvider.future);

      final nowUtc = DateTime.now().toUtc();
      final day0 = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final end7 = day0.add(const Duration(days: _horizonDays7 - 1));
      final end14 = day0.add(
        const Duration(days: _horizonDays14 - 1),
      );

      int count7 = 0;
      int count14 = 0;
      final absentProfiles14 = <String>{};

      for (final a in absences) {
        // PROČ striktně filtrujeme jen `status == 'approved'`:
        // už existující `StaffAbsence.isApproved` bere i legacy NULL jako approved,
        // ale pro tento KPI to uživatelsky chceme přesně podle zadání.
        if (a.status == null || a.status!.isEmpty) continue;
        if (a.status != staffAbsenceStatusApproved) continue;
        if (a.profileId == null || a.profileId!.isEmpty) continue;
        if (a.startDate == null || a.endDate == null) continue;

        final in7 = _overlapsDayRange(
          absStart: a.startDate!,
          absEnd: a.endDate!,
          windowStart: day0,
          windowEndInclusive: end7,
        );
        if (in7) count7++;

        final in14 = _overlapsDayRange(
          absStart: a.startDate!,
          absEnd: a.endDate!,
          windowStart: day0,
          windowEndInclusive: end14,
        );
        if (in14) {
          count14++;
          absentProfiles14.add(a.profileId!);
        }
      }

      return UpcomingAbsencesSummary(
        approvedAbsencesCount7Days: count7,
        approvedAbsencesCount14Days: count14,
        absentMemberProfileIds14Days: absentProfiles14.toList()
          ..sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase())),
      );
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('UpcomingAbsencesProvider error: $e');
        // ignore: avoid_print
        print(st);
      }
      rethrow;
    }
  }
}

