import 'package:falconest/features/owner/models/owner_cash_disposition_request.dart';

/// Žádost o dispozici hotovosti + údaje majitele z embedu `profiles` (admin přehled v jednom SELECTu).
///
/// PROČ: Dispečink potřebuje jméno žadatele bez dalšího dotazu; typ je vedle [OwnerCashDispositionRequest] v owner modulu,
/// protože ho plní [OwnerCashDispositionRepository.getRequestsForTenant].
class AdminOwnerCashDispositionRow {
  const AdminOwnerCashDispositionRow({
    required this.request,
    required this.ownerDisplayName,
    this.ownerEmail,
  });

  final OwnerCashDispositionRequest request;
  final String ownerDisplayName;
  final String? ownerEmail;
}
