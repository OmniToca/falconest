import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';

/// Mapy z [reservation_services] přemapované na klíč `reservationId|serviceId` + fallback podle rezervace.
///
/// PROČ samostatný soubor: stejná pravidla pro cenu a plátce používá Admin (podklady pro fakturaci)
/// i Klientský portál (součet nevyfakturovaných služeb majitele) — jeden zdroj pravdy, žádný drift.
class BillingReservationServiceMaps {
  const BillingReservationServiceMaps({
    required this.priceByResService,
    required this.payerTypeByResService,
    required this.fallbackPricePayerByResId,
  });

  final Map<String, double> priceByResService;
  final Map<String, String> payerTypeByResService;
  final Map<String, List<({double price, String payer})>> fallbackPricePayerByResId;
}

/// Sestaví mapy z řádků [reservation_services] pro výpočet ceny/plátce u úkolů (PRAVIDLO A / fallback).
///
/// Logika je shodná s [billingMonthProvider] v `finance_billing_provider.dart`.
Future<BillingReservationServiceMaps> buildBillingReservationServiceMaps({
  required List<String> reservationIds,
  required String tenantId,
}) async {
  final priceByResService = <String, double>{};
  final payerTypeByResService = <String, String>{};
  final fallbackPricePayerByResId =
      <String, List<({double price, String payer})>>{};

  final ids = reservationIds.where((id) => id.trim().isNotEmpty).toSet().toList();
  if (ids.isEmpty) {
    return BillingReservationServiceMaps(
      priceByResService: priceByResService,
      payerTypeByResService: payerTypeByResService,
      fallbackPricePayerByResId: fallbackPricePayerByResId,
    );
  }

  final servicesByRes = await fetchByReservationIds(ids, tenantId);
  final apartmentServiceIds = <String>{};
  for (final list in servicesByRes.values) {
    for (final rs in list) {
      final id = rs.apartmentServiceId.trim();
      if (id.isNotEmpty) apartmentServiceIds.add(id);
    }
  }
  final aptServiceToServiceId = <String, String>{};
  if (apartmentServiceIds.isNotEmpty) {
    final aptRes = await SupabaseService.safeFrom(
      'apartment_services',
      tenantId,
    ).select('id, service_id').inFilter('id', apartmentServiceIds.toList());
    for (final row in (aptRes as List)) {
      final m = row as Map<String, dynamic>;
      final id = (m['id'] as String?)?.trim();
      final sid = (m['service_id'] as String?)?.trim();
      if (id != null && id.isNotEmpty && sid != null && sid.isNotEmpty) {
        aptServiceToServiceId[id] = sid;
      }
    }
  }
  for (final entry in servicesByRes.entries) {
    final resId = entry.key;
    for (final rs in entry.value) {
      final sid = aptServiceToServiceId[rs.apartmentServiceId];
      final price = (rs.chargedPrice ?? 0).toDouble();
      final payer = rs.payerType ?? 'guest';
      if (sid != null) {
        final key = '$resId|$sid';
        priceByResService[key] = price;
        payerTypeByResService[key] = payer;
      } else {
        fallbackPricePayerByResId.putIfAbsent(resId, () => []).add((
          price: price,
          payer: payer,
        ));
      }
    }
  }

  return BillingReservationServiceMaps(
    priceByResService: priceByResService,
    payerTypeByResService: payerTypeByResService,
    fallbackPricePayerByResId: fallbackPricePayerByResId,
  );
}

/// Určí plátce z metadata.payer_type; legacy: amount_to_collect > 0 implikuje guest.
///
/// Shodné s dřívějším `_resolvePayerType` v `finance_billing_provider.dart`.
String billingResolvePayerType(
  String? metaPayerType,
  double? metaAmountToCollect,
  String clientId,
) {
  if (metaPayerType == 'guest' ||
      metaPayerType == 'owner' ||
      metaPayerType == 'client') {
    return metaPayerType!;
  }
  if ((metaAmountToCollect ?? 0) > 0) return 'guest';
  return clientId.isNotEmpty ? 'client' : 'owner';
}

/// Cena a plátce jednoho úkolu — PRAVIDLO A (rezervace + služba) / PRAVIDLO B (bez páru).
///
/// [t] musí obsahovat alespoň: `metadata`, `client_id`, `reservation_id`, `service_id`.
({double chargedPrice, String payerType}) billingChargedPriceAndPayerForTask(
  Map<String, dynamic> t,
  BillingReservationServiceMaps maps,
) {
  final clientId = (t['client_id'] as String?)?.trim() ?? '';
  final resId = (t['reservation_id'] as String?)?.trim() ?? '';
  final svcId = (t['service_id'] as String?)?.trim() ?? '';
  final resSvcKey = '$resId|$svcId';

  final meta = t['metadata'];
  final metaServicePrice = meta is Map
      ? double.tryParse((meta['service_price']?.toString() ?? '').trim())
      : null;
  final metaAmountToCollect = meta is Map
      ? double.tryParse(
          (meta['amount_to_collect']?.toString() ?? '').trim(),
        )
      : null;
  final metaPayerType = meta is Map
      ? ((meta['payer_type'] as String?)?.trim())
      : null;

  double chargedPrice;
  String payerType;

  if (resId.isNotEmpty && svcId.isNotEmpty) {
    final fromRes = maps.priceByResService[resSvcKey];
    final payerFromRes = maps.payerTypeByResService[resSvcKey];
    if (fromRes != null && payerFromRes != null) {
      chargedPrice = metaServicePrice ?? metaAmountToCollect ?? fromRes;
      payerType =
          (metaPayerType != null && metaPayerType.isNotEmpty)
              ? metaPayerType
              : payerFromRes;
    } else {
      final fallbackList = maps.fallbackPricePayerByResId[resId];
      if (fallbackList != null && fallbackList.length == 1) {
        chargedPrice =
            metaServicePrice ??
            metaAmountToCollect ??
            fallbackList.first.price;
        payerType =
            (metaPayerType != null && metaPayerType.isNotEmpty)
                ? metaPayerType
                : fallbackList.first.payer;
      } else {
        chargedPrice = metaServicePrice ?? metaAmountToCollect ?? 0.0;
        payerType = billingResolvePayerType(
          metaPayerType,
          metaAmountToCollect,
          clientId,
        );
      }
    }
  } else {
    chargedPrice = metaServicePrice ?? metaAmountToCollect ?? 0.0;
    payerType = billingResolvePayerType(
      metaPayerType,
      metaAmountToCollect,
      clientId,
    );
  }

  return (chargedPrice: chargedPrice, payerType: payerType);
}
