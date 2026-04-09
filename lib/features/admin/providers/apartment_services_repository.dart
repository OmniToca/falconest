import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/apartment_service_model.dart';

/// Načte všechny záznamy apartment_services pro daný byt (pro předvyplnění Tabu 2 v dialogu).
///
/// PROČ timeout: Tab 2 „Služby a požadavky“ nesmí donekonečna točit kolečko – při zablokování
/// DB/sítě po 10 s výjimka probublá a UI zobrazí formulář (fallback z finally).
/// Vrátí `checklist_template_id` z [apartment_services] pro dvojici byt + služba z katalogu.
///
/// PROČ: Při vytvoření úkolu s [apartment_id] a [service_id] automaticky navážeme šablonu checklistu
/// uloženou u této vazby (Fáze 3 – zmrazení kopie v `task_checklist_items`).
Future<String?> fetchChecklistTemplateIdForApartmentAndService({
  required String tenantId,
  required String apartmentId,
  required String serviceId,
}) async {
  if (tenantId.isEmpty || apartmentId.isEmpty || serviceId.isEmpty) return null;
  final res = await SupabaseService.safeFrom('apartment_services', tenantId)
      .select('checklist_template_id')
      .eq('apartment_id', apartmentId)
      .eq('service_id', serviceId)
      .maybeSingle();
  if (res == null) return null;
  final v = res['checklist_template_id'];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

Future<List<ApartmentServiceRow>> fetchByApartmentId(String apartmentId, String tenantId) async {
  if (apartmentId.isEmpty || tenantId.isEmpty) return [];
  const timeout = Duration(seconds: 10);
  final res = await SupabaseService.safeFrom('apartment_services', tenantId)
      .select()
      .eq('apartment_id', apartmentId)
      .timeout(timeout);
  final list = res as List;
  return list
      .map((e) => ApartmentServiceRow.fromJson(e as Map<String, dynamic>))
      .where((r) => r.id.isNotEmpty)
      .toList();
}

/// Dvoukrokový zápis: nejdřív smaže všechny stávající apartment_services pro byt, pak vloží nové (jen enabled).
/// [states] = mapa serviceId -> edit state; ukládají se jen záznamy s enabled == true.
/// Ceny [customPriceEur] se ukládají do sloupce custom_price v EUR.
Future<void> saveForApartment({
  required String apartmentId,
  required String tenantId,
  required Map<String, ApartmentServiceEditState> states,
}) async {
  final toInsert = states.values.where((s) => s.enabled).toList();
  final safeAps = SupabaseService.safeFrom('apartment_services', tenantId);
  await safeAps.delete().eq('apartment_id', apartmentId);
  if (toInsert.isEmpty) return;
  for (final s in toInsert) {
    await safeAps.insert({
      'apartment_id': apartmentId,
      'service_id': s.serviceId,
      'custom_price': s.customPriceEur,
      'custom_description': s.customDescription?.trim().isEmpty == true ? null : s.customDescription?.trim(),
      'trigger_type': s.triggerType,
      'schedule_interval': s.scheduleInterval?.trim().isEmpty == true ? null : s.scheduleInterval?.trim(),
      'is_mandatory': s.isMandatory,
      'payer_type': s.payerType,
      'requires_photo': s.requiresPhoto,
      // PROČ: null se do JSON/PostgREST neposílá jako klíč jen pokud vynecháme – explicitně null je v pořádku pro „bez šablony“.
      if (s.checklistTemplateId != null && s.checklistTemplateId!.trim().isNotEmpty)
        'checklist_template_id': s.checklistTemplateId!.trim(),
    });
  }
}
