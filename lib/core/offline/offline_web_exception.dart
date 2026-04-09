/// Výjimka vyhozená při pokusu zařadit mutaci do offline fronty na webové platformě.
///
/// PROČ: Web nemá lokální Drift frontu; dříve [MutationQueueService] na webu dělal no-op
/// a uživatel při výpadku sítě ztrácel data bez zpětné vazby. Fail-fast tímto typem
/// umožní volajícím zachytit situaci a zobrazit lokalizovanou hlášku místo falešného úspěchu.
class OfflineWebException implements Exception {
  OfflineWebException([this.message]);

  /// Krátká technická zpráva (log / debug); UI má používat `errors.offline_web_save_failed`.
  final String? message;

  @override
  String toString() =>
      message ?? 'OfflineWebException: web mutation queue is not available';
}
