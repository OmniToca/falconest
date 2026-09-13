import 'package:flutter/widgets.dart';

import 'package:falconest/core/localization/billing_pdf_translation_bundle.dart';

/// Sestaví mapu řetězců pro PDF podklady ve zvoleném jazyce **z asset JSON** (parita s EasyLocalization).
///
/// **PROČ:** PDF se musí vygenerovat v jazyce zvoleném uživatelem pro export, ne v aktuálním locale UI.
/// Service vrstva dostane už hotové řetězce a neobsahuje ani `.tr()`, ani anglické fallbacky.
Future<Map<String, String>> buildBillingPdfFooterLabelMap(Locale exportLocale) async {
  final bundle = await BillingPdfTranslationBundle.load(exportLocale.languageCode);
  String k(String key) => bundle.tr(key);

  return {
    'report_title': k('admin.finance.billing_pdf_report_title'),
    'client_label': k('admin.finance.billing_client_label'),
    'guest_label': k('admin.finance.billing_guest_label'),
    'reservation_prefix': k('admin.finance.billing_reservation_prefix'),
    'standalone_services': k('admin.finance.billing_standalone_services'),
    'apartment_bound_services': k('admin.finance.billing_apartment_bound_services'),
    'external_services': k('admin.finance.billing_external_services'),
    'scheduled_label': k('admin.finance.billing_scheduled_label'),
    'completed_label': k('admin.finance.billing_completed_label'),
    'date_label': k('admin.finance.billing_date_label'),
    'fallback_client_name': k('admin.finance.billing_fallback_client_name'),
    'total_turnover': k('admin.finance.billing_total_turnover'),
    'paid_by_guests': k('admin.finance.billing_paid_by_guests'),
    'expenses_to_reimburse': k('admin.finance.billing_expenses_to_reimburse'),
    'expenses_section': k('admin.finance.billing_expenses_to_reimburse_section'),
    'monthly_management_fee': k('admin.finance.billing_monthly_management_fee'),
    'task_price_label': k('admin.finance.billing_task_price_label'),
    'task_guest_paid_label': k('admin.finance.billing_task_guest_paid_label'),
    'task_shortfall_due_label': k('admin.finance.billing_task_shortfall_due_label'),
    'final_pay': k('admin.finance.billing_final_owner_pay'),
    'payer': k('admin.finance.billing_payer'),
    'summary_section': k('admin.finance.billing_summary_section'),
    'services_breakdown': k('admin.finance.billing_services_breakdown'),
    'subtotal_per_reservation': k('admin.finance.billing_subtotal_per_reservation'),
    'turnover_short': k('admin.finance.billing_turnover_short'),
    'guest_paid_short': k('admin.finance.billing_guest_paid_short'),
    'placeholder_dash': k('common.placeholder_dash'),
    'file_name_prefix': k('admin.finance.export_pdf_file_name_prefix'),
  };
}

/// Přeložené labely plátců pro PDF (owner / guest / client).
Future<Map<String, String>> buildBillingPdfPayerLabelMap(Locale exportLocale) async {
  final bundle = await BillingPdfTranslationBundle.load(exportLocale.languageCode);
  String k(String key) => bundle.tr(key);

  return {
    'owner': k('admin.finance.billing_payer_owner'),
    'guest': k('admin.finance.billing_payer_guest'),
    'client': k('admin.finance.billing_payer_client'),
  };
}

/// Zobrazovaný název skupiny `external` v PDF — musí být v jazyce exportu.
Future<String> billingPdfExternalGroupDisplayName(Locale exportLocale) async {
  final bundle = await BillingPdfTranslationBundle.load(exportLocale.languageCode);
  return bundle.tr('admin.finance.billing_group_external');
}
