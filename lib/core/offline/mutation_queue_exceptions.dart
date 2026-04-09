// Výjimky pro frontu offline mutací (Drift).
//
// PROČ: Rozlišíme stavy, kdy mutaci nesmíme tiše smazat – buď kvůli chybě kódu
// (neznámý actionType), nebo kvůli poškozenému záznamu (chybí record_id u UPDATE).

/// Neznámý typ akce ve frontě – vyžaduje úpravu aplikace; mutace zůstane v SQLite.
class UnknownMutationTypeException implements Exception {
  UnknownMutationTypeException(this.actionType);
  final String actionType;

  @override
  String toString() => 'UnknownMutationTypeException($actionType)';
}

/// UPDATE/DELETE bez cílového UUID – záznam nelze bezpečně odeslat na server.
class MissingRecordIdException implements Exception {
  MissingRecordIdException({required this.actionType, required this.tableName});
  final String actionType;
  final String tableName;

  @override
  String toString() => 'MissingRecordIdException($actionType, table=$tableName)';
}

/// Prázdný nebo chybějící payload mutace – nesmí se tiše zahodit.
class EmptyQueuedMutationPayloadException implements Exception {
  EmptyQueuedMutationPayloadException([this.detail]);
  final String? detail;

  @override
  String toString() =>
      'EmptyQueuedMutationPayloadException${detail != null ? ': $detail' : ''}';
}

/// Chybí tenant_id v payloadu – bez [SupabaseService.safeFrom] by hrozil zápis mimo scope.
class MissingQueuedMutationTenantIdException implements Exception {
  MissingQueuedMutationTenantIdException({required this.tableName, required this.action});
  final String tableName;
  final String action;

  @override
  String toString() =>
      'MissingQueuedMutationTenantIdException(action=$action, table=$tableName)';
}
