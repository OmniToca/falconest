import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/features/super_admin/services/audit_log_repository.dart';

/// Pomocné funkce pro zobrazení audit logu v „lidské“ podobě.
///
/// PROČ: V DB máme surové hodnoty (UUID tenant_id, systémové názvy tabulek jako „tasks“,
/// kódy akcí jako SOFT_DELETE). Uživateli zobrazujeme přeložené entity (název agentury,
/// „Úkol“, „Smazáno (v koši)“) – tedy polidštění bez změny dat v databázi.

/// Vrátí i18n klíč pro překlad názvu tabulky.
///
/// Systémové názvy tabulek (tasks, profiles, …) se mapují na klíče ve slovníku
/// super_admin.audit_log_table_*, aby UI zobrazovalo česky „Úkol“, „Profil“ atd.
/// Nehardcodujeme řetězce – vše jde přes easy_localization.
String auditLogTableToTranslationKey(String? tableName) {
  if (tableName == null || tableName.isEmpty) {
    return 'super_admin.audit_log_table_unknown';
  }
  switch (tableName) {
    case 'tasks':
      return 'super_admin.audit_log_table_tasks';
    case 'profiles':
      return 'super_admin.audit_log_table_profiles';
    case 'reservations':
      return 'super_admin.audit_log_table_reservations';
    case 'apartments':
      return 'super_admin.audit_log_table_apartments';
    case 'tenant_modules':
      return 'super_admin.audit_log_table_tenant_modules';
    default:
      return 'super_admin.audit_log_table_unknown';
  }
}

/// Vrátí i18n klíč pro překlad typu akce.
///
/// Akce z DB (SOFT_DELETE, UNASSIGN_TASKS, …) se mapují na srozumitelné popisky
/// („Smazáno (v koši)“, „Odebrání úkolů“). Neznámé akce spadnou na obecný klíč.
String auditLogActionToTranslationKey(String actionType) {
  if (actionType.isEmpty) return 'super_admin.audit_log_action_unknown';
  switch (actionType) {
    case AuditActionType.softDelete:
      return 'super_admin.audit_log_action_soft_delete';
    case AuditActionType.softDeleteCascade:
      return 'super_admin.audit_log_action_soft_delete_cascade';
    case 'UNASSIGN_TASKS':
      return 'super_admin.audit_log_action_unassign_tasks';
    case 'MODULE_ACTIVATED':
      return 'super_admin.audit_log_action_module_activated';
    case 'MODULE_DEACTIVATED':
      return 'super_admin.audit_log_action_module_deactivated';
    case 'TRIAL_UPDATED':
      return 'super_admin.audit_log_action_trial_updated';
    default:
      return 'super_admin.audit_log_action_unknown';
  }
}

/// Zkusí z payloadu [details] vybrat lidsky čitelný název entity.
///
/// PROČ: record_id je UUID – pro uživatele nic neříká. Preferujeme enterprise klíč record_name,
/// pak name, title, display_name, subject, label. Jinak volající zobrazí UUID vizuálně potlačené.
String? getAuditLogDisplayNameFromDetails(AuditLogEntry entry) {
  final details = entry.details;
  if (details == null || details.isEmpty) return null;
  final recordName = details['record_name'];
  if (recordName is String && recordName.trim().isNotEmpty) return recordName.trim();
  final candidates = ['name', 'title', 'display_name', 'subject', 'label'];
  for (final key in candidates) {
    final v = details[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// Bezpečně přečte sloupec details (JSONB) a vrátí jeden řádek textu pro zobrazení v UI.
///
/// PROČ: details obsahuje kontext (triggered_by, module_key, price, trial …). Všechny
/// výstupy jdou přes i18n – žádné hardcoded řetězce. Neznámé klíče se přeskakují.
/// Příklad: triggered_by: "reservation" → „Kaskádové smazání kvůli rezervaci“;
/// module_key: "automatic" → „Modul: automatic“.
String? formatAuditLogDetailsForDisplay(Map<String, dynamic>? details) {
  if (details == null || details.isEmpty) return null;
  final parts = <String>[];

  // Kaskádové smazání – důvod (triggered_by z DB)
  final triggeredBy = details['triggered_by']?.toString().trim();
  if (triggeredBy != null && triggeredBy.isNotEmpty) {
    switch (triggeredBy) {
      case 'reservation':
        parts.add('super_admin.audit_log_details_cascade_reservation'.tr());
        break;
      case 'apartment':
        parts.add('super_admin.audit_log_details_cascade_apartment'.tr());
        break;
      case 'profile_soft_delete':
        parts.add('super_admin.audit_log_details_cascade_profile'.tr());
        break;
      default:
        parts.add('super_admin.audit_log_details_cascade_other'.tr());
    }
  }

  // Modul – klíč z tenant_modules (module_key nebo module)
  final moduleKey = details['module_key']?.toString().trim();
  if (moduleKey != null && moduleKey.isNotEmpty) {
    parts.add('super_admin.audit_log_details_module_key'.tr(namedArgs: {'key': moduleKey}));
  } else {
    final module = details['module']?.toString().trim();
    if (module != null && module.isNotEmpty) {
      parts.add('super_admin.audit_log_details_module'.tr(namedArgs: {'module': module}));
    }
  }

  // Cena
  final price = details['price'];
  if (price != null) {
    final priceStr = price is num ? price.toString() : price.toString().trim();
    if (priceStr.isNotEmpty) {
      parts.add('super_admin.audit_log_details_price'.tr(namedArgs: {'price': priceStr}));
    }
  }

  // Trial
  final isTrial = details['is_trial'];
  final trialEndsAt = details['trial_ends_at']?.toString().trim();
  if (isTrial == true || trialEndsAt != null) {
    if (trialEndsAt != null && trialEndsAt.isNotEmpty) {
      parts.add('super_admin.audit_log_details_trial_ends'.tr(namedArgs: {'date': trialEndsAt}));
    } else {
      parts.add('super_admin.audit_log_details_trial'.tr());
    }
  }

  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Zkrátí UUID na prvních 8 znaků pro kompaktní zobrazení, když nemáme display name.
String shortRecordId(String? recordId) {
  if (recordId == null || recordId.isEmpty) return '—';
  if (recordId.length <= 8) return recordId;
  return '${recordId.substring(0, 8)}…';
}

/// Vrátí ikonu podle typu tabulky pro konzistentní vizuál v listu.
///
/// Uživatel rychle rozpozná typ záznamu (úkol, profil, rezervace, byt) bez čtení textu.
IconData getAuditLogIconForTable(String? tableName) {
  if (tableName == null || tableName.isEmpty) return Icons.description_outlined;
  switch (tableName) {
    case 'tasks':
      return Icons.task_alt_outlined;
    case 'profiles':
      return Icons.person_outline;
    case 'reservations':
      return Icons.calendar_today_outlined;
    case 'apartments':
      return Icons.apartment_outlined;
    case 'tenant_modules':
      return Icons.extension_outlined;
    default:
      return Icons.description_outlined;
  }
}
