// Riverpod provider pro iCal Sync – načítání zdrojů, přidávání, synchronizace.
// Oddělený state management pro iCal sekci v detailu apartmánu.
// Spravuje loading stavy, chyby a invalidaci adminReservationsProvider po syncu.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/services/ical_sync_service.dart';

/// Načte seznam iCal zdrojů pro daný apartmán.
final icalSourcesProvider =
    FutureProvider.autoDispose.family<List<IcalSourceRow>, String>((ref, apartmentId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  return IcalSyncService.instance.getSources(apartmentId, tenantId);
});

/// Provider pro Notifier, který spravuje přidávání zdrojů a sync (loading, chyby).
final icalSyncNotifierProvider =
    StateNotifierProvider<IcalSyncNotifier, IcalSyncState>((ref) {
  return IcalSyncNotifier(ref);
});

class IcalSyncState {
  const IcalSyncState({
    this.isAddingSource = false,
    this.addSourceError,
    this.syncingSourceId,
    this.syncError,
  });

  final bool isAddingSource;
  final String? addSourceError;
  final String? syncingSourceId;
  final String? syncError;

  IcalSyncState copyWith({
    bool? isAddingSource,
    String? addSourceError,
    String? syncingSourceId,
    String? syncError,
  }) {
    return IcalSyncState(
      isAddingSource: isAddingSource ?? this.isAddingSource,
      addSourceError: addSourceError,
      syncingSourceId: syncingSourceId ?? this.syncingSourceId,
      syncError: syncError,
    );
  }
}

class IcalSyncNotifier extends StateNotifier<IcalSyncState> {
  IcalSyncNotifier(this._ref) : super(const IcalSyncState());

  final Ref _ref;

  String? get _tenantId => _ref.read(authNotifierProvider).tenantIdForData;

  /// Přidá nový iCal zdroj. Po úspěchu invaliduje icalSourcesProvider.
  /// Vrací null při úspěchu, chybovou zprávu při selhání.
  Future<String?> addSource({
    required String apartmentId,
    required String url,
    required String label,
  }) async {
    final tenantId = _tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      state = state.copyWith(addSourceError: 'Chybí tenant_id');
      return 'Chybí tenant_id';
    }
    state = state.copyWith(isAddingSource: true, addSourceError: null);
    try {
      await IcalSyncService.instance.addSource(
        apartmentId: apartmentId,
        tenantId: tenantId,
        url: url,
        label: label,
      );
      _ref.invalidate(icalSourcesProvider(apartmentId));
      state = state.copyWith(isAddingSource: false, addSourceError: null);
      return null;
    } catch (e) {
      final err = e.toString();
      state = state.copyWith(
        isAddingSource: false,
        addSourceError: err,
      );
      return err;
    }
  }

  /// Odstraní iCal zdroj a invaliduje seznam.
  Future<void> removeSource(String apartmentId, String sourceId) async {
    final tenantId = _tenantId;
    if (tenantId == null || tenantId.isEmpty) return;
    await IcalSyncService.instance.removeSource(sourceId, tenantId);
    _ref.invalidate(icalSourcesProvider(apartmentId));
  }

  /// Synchronizuje jeden iCal URL. Po úspěchu invaliduje rezervace a zdroje.
  /// Při chybě vrací IcalSyncResult s error.
  Future<IcalSyncResult> syncUrl({
    required String apartmentId,
    required String tenantId,
    required String icalUrl,
    String? sourceId,
  }) async {
    state = state.copyWith(
      syncingSourceId: sourceId,
      syncError: null,
    );
    try {
      final result = await IcalSyncService.instance.syncIcalUrl(
        apartmentId: apartmentId,
        tenantId: tenantId,
        icalUrl: icalUrl,
      );
      _ref.invalidate(adminReservationsProvider);
      _ref.invalidate(icalSourcesProvider(apartmentId));
      if (sourceId != null && result.error == null) {
        await IcalSyncService.instance.updateLastSyncedAt(sourceId, tenantId);
        _ref.invalidate(icalSourcesProvider(apartmentId));
      }
      state = state.copyWith(syncingSourceId: null, syncError: result.error);
      return result;
    } catch (e) {
      state = state.copyWith(
        syncingSourceId: null,
        syncError: e.toString(),
      );
      return IcalSyncResult(
        insertedCount: 0,
        skippedDuplicates: 0,
        error: e.toString(),
      );
    }
  }

  void clearAddSourceError() {
    state = state.copyWith(addSourceError: null);
  }

  void clearSyncError() {
    state = state.copyWith(syncError: null);
  }
}
