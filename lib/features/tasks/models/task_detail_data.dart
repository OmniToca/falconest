/// Platformově nezávislý DTO pro detail úkolu na obrazovce TaskDetailScreen.
///
/// Používá se místo TaskLocal + ApartmentLocal, aby se na webu nemusely
/// importovat Isar modely (dart:html neumí 64-bitová čísla z .g.dart).
/// Obsahuje jen pole potřebná pro UI.
class TaskDetailData {
  const TaskDetailData({
    required this.taskId,
    required this.scheduledStart,
    required this.status,
    this.photoUrl,
    this.apartmentName,
    this.apartmentAddress,
    this.apartmentKeybox,
  });

  /// Isar ID úkolu (pro updateTaskStatus na mobilu).
  final int taskId;

  /// Plánovaný začátek úkolu.
  final DateTime scheduledStart;

  /// Stav: pending, in_progress, completed, cancelled.
  final String status;

  /// URL nebo lokální cesta k fotce.
  final String? photoUrl;

  /// Název bytu.
  final String? apartmentName;

  /// Adresa bytu.
  final String? apartmentAddress;

  /// Kód ke klíčům.
  final String? apartmentKeybox;
}
