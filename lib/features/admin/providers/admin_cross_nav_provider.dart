import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Požadavek na přepnutí záložky v [AdminLayout] (IndexedStack).
///
/// PROČ: Dialogy úkolů/rezervací jsou nad root navigator a [AdminTabScope] z nich často
/// není dědičně dostupný – centrální [StateProvider] zajistí spolehlivé přepnutí záložky
/// po zavření dialogu (křížová navigace mezi moduly).
final adminTabJumpRequestProvider = StateProvider<int?>((ref) => null);

/// Nesplněný cíl křížové navigace – po přepnutí záložky příslušná obrazovka otevře detail.
@immutable
class AdminCrossNavPending {
  const AdminCrossNavPending({
    this.apartmentId,
    this.reservationId,
    this.clientId,
    required this.token,
  });

  final String? apartmentId;
  final String? reservationId;
  final String? clientId;
  /// Monotónní čítač – každé nové zadání i [clear] posune token, aby [ref.listen] zachytil i opakovaný stejný ID.
  final int token;
}

/// Správce fronty „otevři entitu na jiné záložce“ po zavření dialogu.
class AdminCrossNavPendingNotifier extends Notifier<AdminCrossNavPending> {
  int _seq = 0;

  @override
  AdminCrossNavPending build() => AdminCrossNavPending(token: _seq);

  void openApartment(String id) {
    final t = id.trim();
    if (t.isEmpty) return;
    state = AdminCrossNavPending(apartmentId: t, token: ++_seq);
  }

  void openReservation(String id) {
    final t = id.trim();
    if (t.isEmpty) return;
    state = AdminCrossNavPending(reservationId: t, token: ++_seq);
  }

  void openClient(String id) {
    final t = id.trim();
    if (t.isEmpty) return;
    state = AdminCrossNavPending(clientId: t, token: ++_seq);
  }

  void clear() {
    state = AdminCrossNavPending(token: ++_seq);
  }
}

final adminCrossNavPendingProvider =
    NotifierProvider<AdminCrossNavPendingNotifier, AdminCrossNavPending>(
  AdminCrossNavPendingNotifier.new,
);
