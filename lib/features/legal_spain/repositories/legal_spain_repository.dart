import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/legal_spain/models/apartment_legal_settings.dart';
import 'package:falconest/features/legal_spain/models/guest_checkin.dart';
import 'package:falconest/features/legal_spain/models/reservation_guest.dart';

/// Přístup k tabulkám legal_spain + RPC veřejného check-inu.
///
/// PROČ: Admin, majitel i worker sdílí stejné hosty. Veřejný token jde jen přes
/// SECURITY DEFINER RPC, aby anon nemohl číst cizí doklady.
class LegalSpainRepository {
  LegalSpainRepository(this._tenantId);

  final String? _tenantId;

  SupabaseClient get _client => SupabaseService.client;

  Future<List<ReservationGuest>> listGuests(String reservationId) async {
    try {
      final res = await SupabaseService.safeFrom('reservation_guests', _tenantId)
          .select()
          .eq('reservation_id', reservationId)
          .order('created_at');
      return (res as List)
          .map((e) => ReservationGuest.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      AppLogger.error('LegalSpainRepository.listGuests', e, st);
      rethrow;
    }
  }

  Future<GuestCheckin?> getCheckin(String reservationId) async {
    try {
      final res = await SupabaseService.safeFrom('guest_checkins', _tenantId)
          .select()
          .eq('reservation_id', reservationId)
          .maybeSingle();
      if (res == null) return null;
      return GuestCheckin.fromJson(Map<String, dynamic>.from(res));
    } catch (e, st) {
      AppLogger.error('LegalSpainRepository.getCheckin', e, st);
      return null;
    }
  }

  /// Zajistí session a vrátí public_token pro odkaz /checkin/:token.
  Future<GuestCheckin> ensureSession(String reservationId) async {
    final raw = await _client.rpc(
      'ensure_legal_checkin_session',
      params: {'p_reservation_id': reservationId},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    return GuestCheckin(
      id: map['id'] as String? ?? '',
      tenantId: _tenantId ?? '',
      reservationId: reservationId,
      publicToken: map['public_token'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
    );
  }

  Future<ReservationGuest> upsertGuest({
    required String reservationId,
    required ReservationGuest guest,
  }) async {
    final payload = {
      ...guest.toUpsertJson(),
      'reservation_id': reservationId,
      if (_tenantId != null && _tenantId.isNotEmpty) 'tenant_id': _tenantId,
    };
    if (guest.id.isEmpty) {
      payload.remove('id');
    }
    final res = await SupabaseService.safeFrom('reservation_guests', _tenantId)
        .upsert(payload)
        .select()
        .single();
    return ReservationGuest.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> deleteGuest(String guestId) async {
    await SupabaseService.safeFrom('reservation_guests', _tenantId)
        .delete()
        .eq('id', guestId);
  }

  Future<void> saveSignature({
    required String guestId,
    required String pngBase64,
  }) async {
    await SupabaseService.safeFrom('reservation_guests', _tenantId).update({
      'signature_png_base64': pngBase64,
      'signed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', guestId);

    // PROČ: Stejná logika jako RPC submit_legal_checkin_signature – všichni 14+ podepsáni → queued.
    try {
      final guestRow = await SupabaseService.safeFrom('reservation_guests', _tenantId)
          .select('reservation_id')
          .eq('id', guestId)
          .maybeSingle();
      final reservationId = guestRow?['reservation_id'] as String?;
      if (reservationId == null) return;
      await ensureSession(reservationId);
      final guests = await listGuests(reservationId);
      final unsigned = guests.where((g) => !g.isMinorUnder14 && !g.isSigned);
      if (unsigned.isEmpty) {
        await SupabaseService.safeFrom('guest_checkins', _tenantId).update({
          'status': 'queued',
          'signed_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'last_error': null,
        }).eq('reservation_id', reservationId);
      }
    } catch (e, st) {
      AppLogger.error('LegalSpainRepository.saveSignature queue', e, st);
    }
  }

  Future<void> enqueuePv(String reservationId) async {
    await _client.rpc(
      'enqueue_ses_pv_for_reservation',
      params: {'p_reservation_id': reservationId},
    );
  }

  Future<ApartmentLegalSettings?> loadApartmentSettings(String apartmentId) async {
    try {
      final row = await SupabaseService.safeFrom(
        'apartment_legal_settings',
        _tenantId,
      ).select().eq('apartment_id', apartmentId).maybeSingle();
      Map<String, dynamic> map = row == null
          ? {
              'apartment_id': apartmentId,
              'tenant_id': _tenantId ?? '',
            }
          : Map<String, dynamic>.from(row);

      try {
        final cred = await SupabaseService.safeFrom('ses_ws_credentials', _tenantId)
            .select('ws_username')
            .eq('apartment_id', apartmentId)
            .maybeSingle();
        if (cred != null) {
          map['ws_username'] = cred['ws_username'];
          map['has_ws_password'] = (cred['ws_username'] as String?)?.isNotEmpty == true;
        }
      } catch (e, st) {
        AppLogger.error('LegalSpainRepository.loadApartmentSettings creds', e, st);
      }
      return ApartmentLegalSettings.fromJson(map);
    } catch (e, st) {
      AppLogger.error('LegalSpainRepository.loadApartmentSettings', e, st);
      return ApartmentLegalSettings(
        apartmentId: apartmentId,
        tenantId: _tenantId ?? '',
      );
    }
  }

  Future<void> saveApartmentSettings({
    required ApartmentLegalSettings settings,
    String? wsPassword,
  }) async {
    await SupabaseService.safeFrom('apartment_legal_settings', _tenantId).upsert(
      settings.toSettingsPayload(),
    );
    if (settings.wsUsername != null || (wsPassword != null && wsPassword.isNotEmpty)) {
      final cred = <String, dynamic>{
        'apartment_id': settings.apartmentId,
        'tenant_id': settings.tenantId,
        'ws_username': settings.wsUsername,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (wsPassword != null && wsPassword.isNotEmpty) {
        cred['ws_password'] = wsPassword;
      }
      await SupabaseService.safeFrom('ses_ws_credentials', _tenantId).upsert(cred);
    }
  }

  /// Dashboard: dnešní a otevřené check-iny (draft/queued/rejected/timeout).
  Future<List<LegalComplianceRow>> loadDashboardRows({
    List<String>? apartmentIds,
    bool slaOnly = false,
  }) async {
    final checkins = await SupabaseService.safeFrom('guest_checkins', _tenantId)
        .select(
          'id, reservation_id, status, last_error, reservations!inner(id, apartment_id, guest_name, start_date, end_date, apartments(name))',
        )
        .order('updated_at', ascending: false)
        .limit(200);
    final list = <LegalComplianceRow>[];
    for (final raw in checkins as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final res = map['reservations'];
      Map<String, dynamic>? rmap;
      if (res is Map) rmap = Map<String, dynamic>.from(res);
      final aptId = rmap?['apartment_id'] as String? ?? '';
      if (apartmentIds != null &&
          apartmentIds.isNotEmpty &&
          !apartmentIds.contains(aptId)) {
        continue;
      }
      String? aptName;
      final apt = rmap?['apartments'];
      if (apt is Map) aptName = apt['name'] as String?;
      final status = (map['status'] as String?) ?? 'draft';
      if (slaOnly &&
          status != 'draft' &&
          status != 'queued' &&
          status != 'rejected' &&
          status != 'timeout') {
        continue;
      }
      list.add(
        LegalComplianceRow(
          reservationId: map['reservation_id'] as String? ?? '',
          apartmentId: aptId,
          apartmentName: aptName,
          guestName: rmap?['guest_name'] as String?,
          startDate: DateTime.tryParse('${rmap?['start_date'] ?? ''}'),
          endDate: DateTime.tryParse('${rmap?['end_date'] ?? ''}'),
          status: status,
          lastError: map['last_error'] as String?,
        ),
      );
    }
    return list;
  }

  Future<List<Map<String, dynamic>>> loadVisitorBookRows() async {
    final res = await SupabaseService.safeFrom('reservation_guests', _tenantId)
        .select(
          'first_name, last_name, second_last_name, document_type, document_number, nationality, birth_date, signed_at, reservation_id, reservations!inner(start_date, end_date, guest_name, apartment_id, apartments(name))',
        )
        .order('created_at', ascending: false)
        .limit(2000);
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Veřejný bootstrap (anon) – null = neplatný token / neaktivní modul.
  static Future<Map<String, dynamic>?> publicBootstrap(String token) async {
    try {
      final raw = await SupabaseService.client.rpc(
        'get_legal_checkin_bootstrap',
        params: {'p_token': token},
      );
      if (raw == null) return null;
      return Map<String, dynamic>.from(raw as Map);
    } catch (e, st) {
      AppLogger.error('LegalSpainRepository.publicBootstrap', e, st);
      return null;
    }
  }

  static Future<ReservationGuest> publicUpsertGuest({
    required String token,
    required Map<String, dynamic> guest,
  }) async {
    final raw = await SupabaseService.client.rpc(
      'upsert_legal_checkin_guest',
      params: {'p_token': token, 'p_guest': guest},
    );
    return ReservationGuest.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  static Future<void> publicSubmitSignature({
    required String token,
    required String guestId,
    required String pngBase64,
  }) async {
    await SupabaseService.client.rpc(
      'submit_legal_checkin_signature',
      params: {
        'p_token': token,
        'p_guest_id': guestId,
        'p_png_base64': pngBase64,
      },
    );
  }

  static String buildCheckinUrl(String token, {String? publicWebOrigin}) {
    var origin = (publicWebOrigin ?? '').trim();
    if (origin.endsWith('/')) {
      origin = origin.substring(0, origin.length - 1);
    }
    if (origin.isEmpty && kIsWeb) {
      origin = Uri.base.origin;
    }
    if (origin.isEmpty) {
      return '/checkin/$token';
    }
    return '$origin/checkin/$token';
  }
}
