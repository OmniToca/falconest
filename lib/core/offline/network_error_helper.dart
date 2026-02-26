import 'dart:async';

/// Rozpozná, zda výjimka odpovídá síťové chybě (offline, timeout).
///
/// Bez importu dart:io – použitelné na webu i mobilu. Kontroluje TimeoutException,
/// typ výjimky (SocketException, ClientException) a text zprávy.
bool isNetworkError(Object e) {
  if (e is TimeoutException) return true;
  final type = e.runtimeType.toString();
  if (type.contains('SocketException')) return true;
  if (type.contains('TimeoutException')) return true;
  if (type.contains('ClientException')) return true;
  if (type.contains('HandshakeException')) return true;
  final msg = e.toString().toLowerCase();
  return msg.contains('socket') ||
      msg.contains('connection') ||
      msg.contains('network') ||
      msg.contains('timeout') ||
      msg.contains('failed host lookup');
}
