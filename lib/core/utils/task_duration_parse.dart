/// Parsuje délku trvání z textového popisu úkolu (cs/en/es) – sdílená logika pro sanitizaci INSERT.
///
/// PROČ: `core` nesmí záviset na `features/calendar`; duplikát regexů z [parseDurationMinutesFromDescription].
int parseDurationMinutesFromDescription(String? description) {
  if (description == null || description.trim().isEmpty) return 60;
  final s = description.trim();
  var minutes = 0;
  final hourReg = RegExp(
    r'(\d+)\s*(?:hod|h|hrs|horas|hour|hours)',
    caseSensitive: false,
  );
  final minReg = RegExp(
    r'(\d+)\s*(?:min|m|mins|minutos|minute|minutes)',
    caseSensitive: false,
  );
  final hourMatch = hourReg.firstMatch(s);
  if (hourMatch != null) {
    final h = int.tryParse(hourMatch.group(1) ?? '0') ?? 0;
    minutes += h * 60;
  }
  final minMatch = minReg.firstMatch(s);
  if (minMatch != null) {
    minutes += int.tryParse(minMatch.group(1) ?? '0') ?? 0;
  }
  return minutes > 0 ? minutes : 60;
}
