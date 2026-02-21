import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Bezpečně parsuje datum z ISO nebo evropského dd.MM.yyyy. Při selhání vrací null (nevyřazujeme uživatele).
DateTime? _parseDateSafe(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is! String) return null;
  final s = v.trim();
  if (s.isEmpty) return null;
  try {
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
  } catch (_) {}
  try {
    return DateFormat('dd.MM.yyyy').parse(s);
  } catch (_) {}
  try {
    return DateFormat('yyyy-MM-dd').parse(s);
  } catch (_) {}
  return null;
}

/// Záznam nepřítomnosti personálu (dovolená, nemoc) – tabulka staff_absences.
/// Odpovídá buď aktivnímu uživateli (profile_id) nebo pozvánce (invitation_id).
class StaffAbsence {
  const StaffAbsence({
    required this.id,
    this.profileId,
    this.invitationId,
    this.startDate,
    this.endDate,
    this.reason,
  });

  final String id;
  /// Vyplněno u aktivního člena (z profiles).
  final String? profileId;
  /// Vyplněno u člena čekajícího na přihlášení (z invitations).
  final String? invitationId;
  /// Null při chybě parsování (evropský dd.MM.yyyy nebo ISO) – taková absence se při přiřazování ignoruje.
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;

  factory StaffAbsence.fromJson(Map<String, dynamic> json) {
    return StaffAbsence(
      id: json['id'] as String? ?? '',
      profileId: _optString(json['profile_id']),
      invitationId: _optString(json['invitation_id']),
      startDate: _parseDateSafe(json['start_date']),
      endDate: _parseDateSafe(json['end_date']),
      reason: (json['reason'] as String?)?.trim(),
    );
  }

  /// True, pokud tato absence patří danému členovi týmu (podle profile_id nebo invitation_id).
  bool belongsTo(TeamMember member) {
    if (profileId != null && profileId == member.profileId) return true;
    if (invitationId != null && (invitationId == member.invitationId || invitationId == member.id)) return true;
    return false;
  }

  static String? _optString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

/// Provider načítající všechny nepřítomnosti v rámci tenanta (pro filtraci při přiřazování úkolů).
final staffAbsencesProvider = FutureProvider<List<StaffAbsence>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  try {
    final res = await SupabaseService.client
        .from('staff_absences')
        .select('id, profile_id, invitation_id, start_date, end_date, reason')
        .eq('tenant_id', tenantId);
    final list = res as List;
    return list
        .map((e) => StaffAbsence.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return [];
  }
});

/// Sjednocený model člena týmu – z profiles (aktivní) nebo invitations (čeká).
///
/// [role] – systémový přístup (sloupec role v DB): 'admin' = manažer/web+mobil, 'worker' = pouze mobil.
/// [roles] – pracovní pozice (sloupec roles v DB): cleaner, driver, maintenance, checkin_agent. Nikdy neobsahuje 'admin'.
/// [isFromInvitation] true = záznam z invitations, false = z profiles.
/// [profileId] – u aktivních = user id, u pozvánek = null.
/// [invitationId] – u pozvánek = id záznamu, u aktivních = null.
/// [dropdownId] – UUID pro dropdown/save: profile.id nebo invitation.id.
/// [weeklyHours] – maximální týdenní úvazek v hodinách (kapacita pro dispečink).
/// [startDate] / [endDate] – platnost smlouvy (nástup/odchod). Pro přiřazování úkolů platí Pravidlo B.
class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    this.email,
    required this.role,
    required this.roles,
    required this.isFromInvitation,
    this.profileId,
    this.invitationId,
    this.weeklyHours = 40,
    this.startDate,
    this.endDate,
    this.zonePreferences,
    this.lastSignInAt,
    this.systemRole,
  });

  final String id;
  final String name;
  final String? email;
  /// Systémový přístup: 'admin' (manažer) nebo 'worker' (pracovník pouze mobil).
  final String role;
  /// Pracovní pozice: cleaner, driver, maintenance, checkin_agent (neobsahuje admin).
  final List<String> roles;
  final bool isFromInvitation;
  final String? profileId;
  final String? invitationId;
  /// Status pro UI: 'active' (profiles) nebo 'pending' (invitations).
  String get status => isFromInvitation ? 'pending' : 'active';
  /// UUID pro dropdown/save: profile.id nebo invitation.id. Obojí je UUID – persistuje se do tasks.assigned_to.
  String get dropdownId => profileId ?? id;
  /// Maximální týdenní úvazek v hodinách (default 40). Pro vyvažování zátěže.
  final int weeklyHours;
  /// Datum nástupu (smlouva od). Null = bez omezení.
  final DateTime? startDate;
  /// Datum odchodu (smlouva do). Null = neurčito.
  final DateTime? endDate;
  /// Žebříček preferencí oblastí: zone_id -> priorita (1 = nejraději, 2 = dojedu).
  /// Pouze u aktivních z profiles; u pending (invitations) null.
  final Map<String, int>? zonePreferences;
  /// Datum posledního přihlášení (profiles.last_sign_in_at). Pro Manager Insights – přehled aktivity personálu.
  final DateTime? lastSignInAt;
  /// Systémová role z DB (profiles.role): 'admin' nebo 'worker'. Pro zobrazení štítku Admin na kartě.
  final String? systemRole;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'roles': roles,
        'weekly_hours': weeklyHours,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'zone_preferences': zonePreferences != null && zonePreferences!.isNotEmpty
            ? zonePreferences
            : null,
      };

  TeamMember copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    List<String>? roles,
    bool? isFromInvitation,
    String? profileId,
    String? invitationId,
    int? weeklyHours,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, int>? zonePreferences,
    DateTime? lastSignInAt,
    String? systemRole,
  }) =>
      TeamMember(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        roles: roles ?? this.roles,
        isFromInvitation: isFromInvitation ?? this.isFromInvitation,
        profileId: profileId ?? this.profileId,
        invitationId: invitationId ?? this.invitationId,
        weeklyHours: weeklyHours ?? this.weeklyHours,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        zonePreferences: zonePreferences ?? this.zonePreferences,
        lastSignInAt: lastSignInAt ?? this.lastSignInAt,
        systemRole: systemRole ?? this.systemRole,
      );
}

/// Pracovní pozice (sloupec roles v DB) – klíče pro Checkboxy a Task Automator. Neobsahuje systémovou roli admin.
const List<String> teamJobRoleKeys = ['cleaner', 'driver', 'maintenance', 'checkin_agent'];

/// Systémový přístup (sloupec role v DB): admin = manažer (web+mobil), worker = pouze mobil.
const List<String> systemRoleValues = ['admin', 'worker'];

/// Volitelný datum z JSON (pro start_date, end_date). Podporuje ISO i dd.MM.yyyy. Při selhání null.
DateTime? _parseDateOptional(dynamic v) => _parseDateSafe(v);

/// Volitelný timestamp z JSON (pro last_sign_in_at). Podporuje ISO string a DateTime.
DateTime? _parseDateTimeOptional(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v.trim());
  return null;
}

/// Bezpečně parsuje zone_preferences z JSONB – mapa zone_id -> priorita. 1 = nejraději, -1 = Hard Blacklist.
/// Při null, prázdném objektu nebo neplatné struktuře vrací null.
Map<String, int>? _parseZonePreferences(dynamic raw) {
  if (raw == null) return null;
  if (raw is! Map) return null;
  final result = <String, int>{};
  for (final e in raw.entries) {
    final key = e.key?.toString().trim();
    if (key == null || key.isEmpty) continue;
    final val = e.value;
    int? prio;
    if (val is int) {
      prio = val;
    } else if (val is num) {
      prio = val.toInt();
    } else if (val is String) {
      prio = int.tryParse(val);
    }
    if (prio != null && (prio > 0 || prio == -1)) result[key] = prio;
  }
  return result.isEmpty ? null : result;
}

/// Vrátí pouze pracovní pozice z JSON (roles array) – vyfiltruje jen hodnoty z teamJobRoleKeys, nikdy ne 'admin'.
List<String> _parseJobRolesFromJson(Map<String, dynamic> json) {
  final rolesRaw = json['roles'];
  if (rolesRaw != null && rolesRaw is List) {
    return rolesRaw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty && teamJobRoleKeys.contains(e))
        .toList();
  }
  final roleRaw = json['role'];
  if (roleRaw != null && roleRaw.toString().trim() == 'worker') {
    return ['cleaner'];
  }
  return [];
}

/// Provider načítající členy týmu – JEN profiles (Ghost Profile Strategy).
///
/// Každý zaměstnanec (Active i Pending) má řádek v profiles.
/// status='pending' = čeká na registraci, status='active' = přihlášen.
final adminTeamProvider = FutureProvider<List<TeamMember>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  try {
    final result = <TeamMember>[];
    dynamic profilesRes;
    try {
      profilesRes = await SupabaseService.client
          .from('profiles')
          .select('id, name, first_name, last_name, email, role, roles, status, weekly_hours, start_date, end_date, zone_preferences, last_sign_in_at')
          .eq('tenant_id', tenantId)
          .isFilter('deleted_at', null)
          .neq('role', 'super_admin')
          .order('status');
    } on Object catch (_) {
      try {
        profilesRes = await SupabaseService.client
            .from('profiles')
            .select('id, name, first_name, last_name, email, role, roles, status, weekly_hours')
            .eq('tenant_id', tenantId)
            .isFilter('deleted_at', null)
            .neq('role', 'super_admin')
            .order('status');
      } on Object catch (_) {
        try {
          profilesRes = await SupabaseService.client
              .from('profiles')
              .select('id, name, first_name, last_name, email, role, roles')
              .eq('tenant_id', tenantId)
              .isFilter('deleted_at', null)
              .neq('role', 'super_admin')
              .order('status');
        } on Object catch (_) {
          return [];
        }
      }
    }
    final profilesList = profilesRes is List ? profilesRes : <dynamic>[];

    for (final p in profilesList) {
      try {
        final map = p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
        final id = map['id']?.toString() ?? '';
        final appRole = map['role']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        if (appRole == 'super_admin') continue;

        final first = (map['first_name']?.toString() ?? '').trim();
        final last = (map['last_name']?.toString() ?? '').trim();
        var name = '$first $last'.trim();
        if (name.isEmpty) name = (map['name']?.toString() ?? '').trim();
        if (name.isEmpty) name = (map['email']?.toString() ?? '').trim();

        final status = (map['status']?.toString() ?? 'active').toLowerCase();
        final isPending = status == 'pending';

        final systemRole = (appRole == 'admin' || appRole == 'manager') ? 'admin' : 'worker';
        List<String> jobRoles = _parseJobRolesFromJson(map);
        if (jobRoles.isEmpty && appRole == 'worker') jobRoles = ['cleaner'];

        final rawHours = map['weekly_hours'];
        int hours = 40;
        if (rawHours != null) {
          if (rawHours is int) {
            hours = rawHours;
          } else if (rawHours is num) {
            hours = rawHours.toInt();
          }
        }
        final startDate = _parseDateOptional(map['start_date']);
        final endDate = _parseDateOptional(map['end_date']);
        final zonePreferences = _parseZonePreferences(map['zone_preferences']);
        final lastSignInAt = _parseDateTimeOptional(map['last_sign_in_at']);

        result.add(TeamMember(
          id: id,
          name: name.isNotEmpty ? name : 'Neznámý',
          email: (map['email']?.toString() ?? '').trim().isEmpty ? null : map['email']?.toString(),
          role: systemRole,
          roles: jobRoles,
          isFromInvitation: isPending,
          profileId: id,
          invitationId: null,
          weeklyHours: hours,
          startDate: startDate,
          endDate: endDate,
          zonePreferences: zonePreferences,
          lastSignInAt: lastSignInAt,
          systemRole: appRole.isNotEmpty ? appRole : systemRole,
        ));
      } catch (e) {
        // ignore: avoid_print
        print('--- CHYBA PARSOVÁNÍ ČLENA TÝMU: $e');
      }
    }

    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  } catch (e) {
    // ignore: avoid_print
    print('--- CHYBA NAČÍTÁNÍ TÝMU: $e');
    return [];
  }
});
