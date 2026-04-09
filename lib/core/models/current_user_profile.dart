/// Model profilu aktuálně přihlášeného uživatele – jméno a e-mail.
///
/// Používá drawer (Worker), záhlaví administrace a záložku profilu v Nastavení.
class CurrentUserProfile {
  const CurrentUserProfile({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;
}
