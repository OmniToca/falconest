import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;

/// Helper pro vytvoření odolných Supabase Realtime streamů s automatickým reconnectem.
///
/// PROČ: Supabase WebSocket (Code 1000) emituje chyby, které se přes `await for` propouští
/// do Riverpodu a UI padá do AsyncError. Tento helper používá `StreamController` + `listen`
/// místo `await for` – chyby zachytí v `onError`/`onDone`, nikdy je nepropaguje dál.
/// Riverpod tedy nikdy nedostane chybový event a UI zůstane stabilní.
///
/// VZNIK: Vytvořeno na základě analýzy RealtimeSubscribeException(status: channelError,
/// details: RealtimeCloseEvent(code: 1000)). await for propouští unhandled exceptions
/// skrze Dart Zones.
///
/// POUŽITÍ:
/// ```dart
/// return resilientSupabaseStream<List<Map<String, dynamic>>>(
///   streamBuilder: () => SupabaseService.client
///       .from('employee_cash_wallets')
///       .stream(primaryKey: ['id'])
///       .inFilter('tenant_id', [tenantId])
///       .limit(500),
///   debugLabel: 'watchWalletsRaw',
/// );
/// ```
///
/// STRICT: Nikdy nevoláme controller.addError() – tím bychom zničili celý smysl helperu.
Stream<T> resilientSupabaseStream<T>({
  required Stream<T> Function() streamBuilder,
  String? debugLabel,
}) {
  bool isCancelled = false;
  StreamSubscription<T>? sub;
  StreamController<T>? controllerRef;

  controllerRef = StreamController<T>.broadcast(
    onCancel: () {
      isCancelled = true;
      sub?.cancel();
      sub = null;
      controllerRef?.close();
    },
  );
  final controller = controllerRef;

  void connect() {
    if (isCancelled || controller.isClosed) return;
    sub = streamBuilder().listen(
      (data) {
        if (!isCancelled && !controller.isClosed) {
          controller.add(data);
        }
      },
      onError: (e, st) {
        if (kDebugMode && debugLabel != null) {
          // ignore: avoid_print
          print('$debugLabel: stream error, reconnecting in 2s: $e');
        }
        sub?.cancel();
        sub = null;
        Future.delayed(const Duration(seconds: 2), () {
          if (!isCancelled && !controller.isClosed) connect();
        });
      },
      onDone: () {
        sub?.cancel();
        sub = null;
        Future.delayed(const Duration(seconds: 2), () {
          if (!isCancelled && !controller.isClosed) connect();
        });
      },
      cancelOnError: false,
    );
  }

  connect();
  return controller.stream;
}
