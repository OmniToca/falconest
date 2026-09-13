import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/owner_view_impersonation_providers.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/features/owner/models/owner_cash_disposition_request.dart';
import 'package:falconest/features/owner/models/owner_cash_transit_settlement.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';
import 'package:falconest/features/owner/repositories/reservation_cash_transit_repository.dart';

/// Po nastavení indexu (např. 5 = Vyúčtování) přepne [OwnerLayout] záložku a hodnotu vymaže.
///
/// PROČ: Nástěnka nemá přímý přístup k `setState` layoutu – sdílený signál přes Riverpod.
final ownerPortalTabIndexRequestProvider = StateProvider<int?>((ref) => null);

/// Dostupný zůstatek průtokové hotovosti majitele v měně tenanta (EUR/CZK/…).
///
/// Výpočet: součet `owner_cash_transit_settlements.amount` minus součet nevyčerpaných
/// schválených žádostí (`owner_cash_disposition_requests.amount - used_amount`).
/// Schválení žádosti na 250 EUR tedy neodečte celý settlement 666 EUR, ale jen rezervovanou částku.
final ownerAvailableBalanceProvider = FutureProvider.autoDispose<double>((
  ref,
) async {
  final auth = ref.watch(authNotifierProvider);
  final tenantId = auth.tenantIdForData;
  final profileId = ref.watch(effectiveProfileIdProvider);
  if (tenantId == null ||
      tenantId.isEmpty ||
      profileId == null ||
      profileId.isEmpty) {
    return 0;
  }
  final currency =
      ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
  try {
    // Diagnostika dvojnásobného „Dostupný zůstatek“ – UI čte tento provider (owner.cash_balance_label).
    if (kDebugMode) {
      AppLogger.debug(
        'OwnerBalanceDebug[ownerAvailableBalanceProvider] start tenantId=$tenantId '
        'profileId=$profileId currency=$currency (zdroj: Supabase, bez Isar/Drift)',
      );
    }
    final v =
        await ReservationCashTransitRepository.getAvailableBalanceForOwner(
          tenantId: tenantId,
          ownerProfileId: profileId,
          currencyCode: currency,
        );
    if (kDebugMode) {
      AppLogger.debug(
        'OwnerBalanceDebug[ownerAvailableBalanceProvider] výsledek pro UI=$v $currency',
      );
    }
    if (v.isNaN || v.isInfinite) return 0;
    return v;
  } catch (e, st) {
    debugPrint('Chyba při čtení zůstatku majitele (ownerAvailableBalanceProvider): $e');
    debugPrint('$st');
    return 0;
  }
});

/// Settlement řádky, proti kterým lze vytvořit žádost o dispozici (stejný filtr jako zůstatek).
final ownerAvailableSettlementsProvider =
    FutureProvider.autoDispose<List<OwnerCashTransitSettlement>>((ref) async {
      final auth = ref.watch(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      final profileId = ref.watch(effectiveProfileIdProvider);
      if (tenantId == null ||
          tenantId.isEmpty ||
          profileId == null ||
          profileId.isEmpty) {
        return [];
      }
      final currency =
          ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
      try {
        return await ReservationCashTransitRepository.listAvailableSettlementsForOwner(
          tenantId: tenantId,
          ownerProfileId: profileId,
          currencyCode: currency,
        );
      } catch (e, st) {
        debugPrint(
          'Chyba při čtení settlementů majitele (ownerAvailableSettlementsProvider): $e',
        );
        debugPrint('$st');
        return [];
      }
    });

/// Historie žádostí majitele o dispozici (nejnovější první z repozitáře).
final ownerCashRequestsProvider =
    FutureProvider.autoDispose<List<OwnerCashDispositionRequest>>((ref) async {
      final auth = ref.watch(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      final profileId = ref.watch(effectiveProfileIdProvider);
      if (tenantId == null ||
          tenantId.isEmpty ||
          profileId == null ||
          profileId.isEmpty) {
        return [];
      }
      try {
        return await OwnerCashDispositionRepository.getRequestsForOwner(
          tenantId: tenantId,
          ownerProfileId: profileId,
        );
      } catch (e, st) {
        debugPrint('Chyba při čtení žádostí majitele (ownerCashRequestsProvider): $e');
        debugPrint('$st');
        return [];
      }
    });
