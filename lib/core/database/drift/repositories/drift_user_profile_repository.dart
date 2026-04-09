import 'package:drift/drift.dart';

import 'package:falconest/core/models/current_user_profile.dart';
import 'package:falconest_drift/app_database.dart' as drift_db;

/// Lokální cache profilu přihlášeného uživatele (`profiles` přes auth_id).
///
/// PROČ: Drawer a dialogy nesmí při každém otevření volat Supabase; data obnoví worker sync.
class DriftUserProfileRepository {
  DriftUserProfileRepository(this._db);

  final drift_db.AppDatabase _db;

  /// Sleduje cache pro dané `auth.users.id`.
  Stream<drift_db.DriftUserProfileCache?> watchByAuthUserId(String authUserId) {
    if (authUserId.isEmpty) return Stream.value(null);
    return (_db.select(_db.userProfilesCache)..where((t) => t.id.equals(authUserId)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Zapíše nebo přepíše řádek cache z odpovědi Supabase (po synci).
  ///
  /// [expectedTenantId] – pokud je neprázdný a řádek má jiný `tenant_id`, zápis přeskočíme (multi-tenant).
  Future<void> upsertFromProfileMap({
    required String authUserId,
    required Map<String, dynamic> map,
    String expectedTenantId = '',
  }) async {
    if (authUserId.isEmpty) return;
    final rowTid = map['tenant_id']?.toString().trim() ?? '';
    if (expectedTenantId.isNotEmpty &&
        rowTid.isNotEmpty &&
        rowTid != expectedTenantId) {
      return;
    }

    final updated = _parseDateTime(map['updated_at']) ?? DateTime.now().toUtc();
    final companion = drift_db.UserProfilesCacheCompanion.insert(
      id: authUserId,
      tenantId: rowTid,
      firstName: Value(_optString(map['first_name'])),
      lastName: Value(_optString(map['last_name'])),
      profileDisplayName: Value(_optString(map['name'])),
      email: Value(_optString(map['email'])),
      avatarUrl: Value(_optString(map['avatar_url'])),
      role: Value((map['role']?.toString() ?? '').trim()),
      updatedAt: updated,
    );

    await _db.into(_db.userProfilesCache).insert(
          companion,
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Mapuje cache na model pro UI (stejná logika jako dřívější Supabase provider).
  static CurrentUserProfile toCurrentUserProfile(
    drift_db.DriftUserProfileCache? row,
    String emailFromAuth,
  ) {
    if (row == null) {
      return CurrentUserProfile(name: '', email: emailFromAuth);
    }
    final first = (row.firstName ?? '').trim();
    final last = (row.lastName ?? '').trim();
    var name = '$first $last'.trim();
    if (name.isEmpty) {
      name = (row.profileDisplayName ?? '').trim();
    }
    final emailFromRow = (row.email ?? '').trim();
    final email = emailFromRow.isNotEmpty ? emailFromRow : emailFromAuth;
    return CurrentUserProfile(name: name, email: email);
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc();
  }

  static String? _optString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
