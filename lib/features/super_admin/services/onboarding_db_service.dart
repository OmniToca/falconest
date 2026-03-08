import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/super_admin/services/master_excel_parser.dart';

/// Služba pro zápis naparsovaných dat z White-Glove Onboarding Wizardu do Supabase.
///
/// Provede sekvenční import v pořadí respektujícím relační vazby a cizí klíče.
/// Každý insert obsahuje [tenantId] pro multi-tenant izolaci.
class OnboardingDbService {
  OnboardingDbService._();

  /// Mapuje kód služby z Excelu na validní service_type v DB.
  /// Excel může obsahovat např. transfer_in, transfer_out, check_in, check_out –
  /// DB akceptuje pouze cleaning, transfer, maintenance, extra.
  static String _mapServiceCodeToType(String code) {
    final c = code.trim().toLowerCase();
    if (c == 'cleaning') return 'cleaning';
    if (c.contains('transfer')) return 'transfer';
    if (c == 'maintenance') return 'maintenance';
    return 'extra';
  }

  /// Mapuje plátce z Excelu (guest/owner/tenant) na payer_type v apartment_services.
  /// apartment_services CHECK: pouze 'owner' nebo 'guest'.
  static String _mapPayerToDb(String payer) {
    final p = payer.trim().toLowerCase();
    return p == 'owner' ? 'owner' : 'guest';
  }

  /// Provede finální import všech naparsovaných dat do databáze.
  ///
  /// [tenantId] – agentura, do které se data zapisují.
  /// [staff] – personál z listu 01_Personal.
  /// [services] – katalog služeb z listu 02_Katalog_Sluzeb.
  /// [apartments] – apartmány s majiteli z listu 03_Portfolio.
  ///
  /// Vrhá [Exception] při jakékoli chybě (např. DB constraint, RLS).
  static Future<void> importTenantData({
    required String tenantId,
    required List<ParsedStaff> staff,
    required List<ParsedService> services,
    required List<ParsedApartment> apartments,
  }) async {
    final client = SupabaseService.client;

    // ═══════════════════════════════════════════════════════════════════════════
    // KROK A: SLUŽBY (tenant_services)
    // ═══════════════════════════════════════════════════════════════════════════
    // Nejprve vložíme katalog služeb – nejsou závislé na žádné jiné tabulce.
    // Mapa serviceCodeToId potřebná pro pozdější vazby apartment_services.
    // Deduplikace: Kontrola existujících služeb – idempotentní import (lze spustit opakovaně).
    final serviceCodeToId = <String, String>{};
    final serviceCodeToPayer = <String, String>{};
    final existingServicesRes = await client
        .from('tenant_services')
        .select('id, service_type, name')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);
    final existingServiceKeyToId = <String, String>{};
    for (final row in existingServicesRes as List) {
      final m = row as Map<String, dynamic>;
      final st = (m['service_type']?.toString() ?? '').trim();
      final nm = (m['name']?.toString() ?? '').trim();
      final id = (m['id']?.toString() ?? '').trim();
      if (st.isNotEmpty && nm.isNotEmpty && id.isNotEmpty) {
        existingServiceKeyToId['$st|$nm'] = id;
      }
    }
    for (final s in services) {
      final code = s.serviceCode.trim().toLowerCase();
      if (code.isEmpty) continue;

      final serviceType = _mapServiceCodeToType(s.serviceCode);
      final name = s.name.trim().isEmpty ? s.serviceCode : s.name.trim();
      final dedupKey = '$serviceType|$name';
      final existingId = existingServiceKeyToId[dedupKey];
      if (existingId != null && existingId.isNotEmpty) {
        serviceCodeToId[code] = existingId;
        serviceCodeToPayer[code] = _mapPayerToDb(s.payer);
        continue;
      }
      final res = await client.from('tenant_services').insert({
        'tenant_id': tenantId,
        'name': name,
        'service_type': serviceType,
        'default_price': s.priceEur,
        'duration_minutes': s.durationMinutes ?? 60,
        'is_active': true,
        'required_role': s.requiredRole.trim().isEmpty ? 'any' : s.requiredRole.trim().toLowerCase(),
      }).select('id').single();

      final id = res['id'] as String?;
      if (id == null || id.isEmpty) {
        throw Exception('Nepodařilo se získat ID služby pro kód: ${s.serviceCode}');
      }
      serviceCodeToId[code] = id;
      serviceCodeToPayer[code] = _mapPayerToDb(s.payer);
      existingServiceKeyToId[dedupKey] = id;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // KROK B: MAJITELÉ A PERSONÁL (profiles + invitations)
    // ═══════════════════════════════════════════════════════════════════════════
    // Ghost profile strategie: vložíme profil se status=pending (bez auth_id).
    // Poté vytvoříme pozvánku – uživatel se později zaregistruje a propojí se s profilem.
    // Mapa ownerEmailToProfileId potřebná pro apartmány – každý apartmán odkazuje
    // na majitele (owner_id). Majitelé pocházejí z ParsedApartment, personál z ParsedStaff.
    //
    // DEDUPLIKACE A OCHRANA PŘED CHYBOU 23505 (profiles_email_tenant_uniq):
    // Více apartmánů může mít stejného majitele (stejný e-mail). Personál a majitelé
    // mohou sdílet e-mail nebo již v DB existovat. Před INSERT vždy načteme existující
    // profily a vkládáme POUZE ty, které v DB ještě nejsou – jinak by došlo k porušení
    // unikátního omezení na (email, tenant_id).
    final ownerEmailToProfileId = <String, String>{};
    final uniqueEmails = <String>{
      ...staff.map((s) => s.email.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ...apartments.map((a) => a.ownerEmail.trim().toLowerCase()).where((e) => e.isNotEmpty),
    };
    final uniqueEmailsList = uniqueEmails.toList();
    if (uniqueEmailsList.isEmpty) {
      // Žádní lidé k importu – pokračujeme do Kroku C
    } else {
      final existingRes = await client
          .from('profiles')
          .select('id, email')
          .eq('tenant_id', tenantId)
          .inFilter('email', uniqueEmailsList);
      final existingProfiles = <String, String>{};
      for (final row in existingRes as List) {
        final m = row as Map<String, dynamic>;
        final e = (m['email']?.toString() ?? '').trim().toLowerCase();
        final id = (m['id']?.toString() ?? '').trim();
        if (e.isNotEmpty && id.isNotEmpty) {
          existingProfiles[e] = id;
        }
      }

      // B1: Unikátní majitelé z apartmánů – vkládáme jen ty, kteří v existingProfiles nejsou
      for (final a in apartments) {
        final email = a.ownerEmail.trim().toLowerCase();
        if (email.isEmpty || ownerEmailToProfileId.containsKey(email)) continue;

        final existingId = existingProfiles[email];
        if (existingId != null && existingId.isNotEmpty) {
          ownerEmailToProfileId[email] = existingId;
          continue;
        }

        final (firstName, lastName) = _splitName(a.ownerName);
        final profileRes = await client.from('profiles').insert({
          'tenant_id': tenantId,
          'email': a.ownerEmail.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'name': a.ownerName.trim().isEmpty ? a.ownerEmail : a.ownerName.trim(),
          'status': 'pending',
          'role': 'property_owner',
        }).select('id').single();

        final profileId = profileRes['id'] as String?;
        if (profileId == null || profileId.isEmpty) {
          throw Exception('Nepodařilo se vytvořit profil pro majitele: ${a.ownerEmail}');
        }
        ownerEmailToProfileId[email] = profileId;
        existingProfiles[email] = profileId;

        await client.from('invitations').insert({
          'tenant_id': tenantId,
          'profile_id': profileId,
          'email': a.ownerEmail.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'role': 'property_owner',
        });
      }

      // B2: Personál (staff) – vkládáme jen ty, kteří v existingProfiles nejsou.
      // Systémová profese z Excelu (systemRole) se zapisuje do sloupce roles jako pole.
      for (final s in staff) {
        final email = s.email.trim().toLowerCase();
        if (email.isEmpty || existingProfiles.containsKey(email)) continue;

        final role = _normalizeStaffRole(s.role);
        final jobRoles = s.systemRole.trim().isEmpty ? <String>[] : [s.systemRole.trim().toLowerCase()];
        final (firstName, lastName) = _splitName(s.name);
        final profileRes = await client.from('profiles').insert({
          'tenant_id': tenantId,
          'email': s.email.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'name': s.name.trim(),
          'status': 'pending',
          'role': role,
          'roles': jobRoles,
        }).select('id').single();

        final profileId = profileRes['id'] as String?;
        if (profileId == null || profileId.isEmpty) {
          throw Exception('Nepodařilo se vytvořit profil pro personál: ${s.email}');
        }
        existingProfiles[email] = profileId;

        await client.from('invitations').insert({
          'tenant_id': tenantId,
          'profile_id': profileId,
          'email': s.email.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'role': role,
          'roles': jobRoles,
        });
      }

      // CRM: Vytvoření klientské karty pro majitele z Excelu – záložka Klienti, fakturace externích úkolů.
      // Majitelé mají profile_id (propojení s Klientským portálem). Idempotentní – pouze chybějící.
      final ownerEmailsRaw = apartments
          .map((a) => a.ownerEmail.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (ownerEmailsRaw.isNotEmpty) {
        final existingClientsRes = await client
            .from('clients')
            .select('id, email')
            .eq('tenant_id', tenantId)
            .isFilter('deleted_at', null)
            .inFilter('email', ownerEmailsRaw);
        final existingClientEmails = <String>{};
        for (final row in existingClientsRes as List) {
          final m = row as Map<String, dynamic>;
          final email = (m['email']?.toString() ?? '').trim().toLowerCase();
          if (email.isNotEmpty) existingClientEmails.add(email);
        }
        for (final a in apartments) {
          final emailKey = a.ownerEmail.trim().toLowerCase();
          if (emailKey.isEmpty || existingClientEmails.contains(emailKey)) continue;
          final profileId = ownerEmailToProfileId[emailKey];
          if (profileId == null || profileId.isEmpty) continue;
          final name = a.ownerName.trim().isEmpty ? a.ownerEmail : a.ownerName.trim();
          await client.from('clients').insert({
            'tenant_id': tenantId,
            'name': name,
            'email': a.ownerEmail.trim(),
            'phone': a.ownerPhone?.trim().isNotEmpty == true ? a.ownerPhone!.trim() : null,
            'client_type': 'owner',
            'profile_id': profileId,
          });
          existingClientEmails.add(emailKey);
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // KROK C: APARTMÁNY (apartments + apartment_owners)
    // ═══════════════════════════════════════════════════════════════════════════
    // Apartmány neobsahují přímý owner_id – vazba je přes apartment_owners.
    // Pro každý apartmán: 1) vložíme apartments, 2) vložíme apartment_owners.
    // Ukládáme apartment_id do mapy pro KROK D – potřebujeme propojit apartmán
    // s jeho aktivními službami v apartment_services.
    final apartmentCodeToId = <String, String>{};
    for (final a in apartments) {
      final ownerEmail = a.ownerEmail.trim().toLowerCase();
      final ownerProfileId = ownerEmailToProfileId[ownerEmail];
      if (ownerProfileId == null || ownerProfileId.isEmpty) {
        throw Exception('Majitel s e-mailem ${a.ownerEmail} nenalezen. Import majitelů proběhl před apartmány.');
      }

      final aptRes = await client.from('apartments').insert({
        'tenant_id': tenantId,
        'name': a.name.trim().isEmpty ? a.apartmentCode : a.name.trim(),
        'code': a.apartmentCode.trim(),
      }).select('id').single();

      final apartmentId = aptRes['id'] as String?;
      if (apartmentId == null || apartmentId.isEmpty) {
        throw Exception('Nepodařilo se vytvořit apartmán: ${a.apartmentCode}');
      }
      apartmentCodeToId[a.apartmentCode.trim()] = apartmentId;

      await client.from('apartment_owners').insert({
        'apartment_id': apartmentId,
        'owner_id': ownerProfileId,
      });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // KROK D: VAZBY SLUŽEB (apartment_services)
    // ═══════════════════════════════════════════════════════════════════════════
    // Pro každý apartmán a každou aktivní službu (kód z activeServices) vytvoříme
    // záznam v apartment_services. Spouštěč (trigger_type) bereme z katalogu
    // (ParsedService.triggerType) – mapa parsedServicesByCode podle kódu služby.
    final parsedServicesByCode = <String, ParsedService>{
      for (final svc in services)
        svc.serviceCode.trim().toLowerCase(): svc,
    };

    for (final a in apartments) {
      final apartmentId = apartmentCodeToId[a.apartmentCode.trim()];
      if (apartmentId == null || apartmentId.isEmpty) continue;

      for (final code in a.activeServices) {
        final svcCode = code.trim().toLowerCase();
        final serviceId = serviceCodeToId[svcCode];
        if (serviceId == null || serviceId.isEmpty) continue;

        final payerType = serviceCodeToPayer[svcCode] ?? 'guest';
        final parsedSvc = parsedServicesByCode[svcCode];
        final triggerType = (parsedSvc?.triggerType.trim().isEmpty ?? true)
            ? 'on_demand'
            : parsedSvc!.triggerType.trim().toLowerCase();

        await client.from('apartment_services').insert({
          'tenant_id': tenantId,
          'apartment_id': apartmentId,
          'service_id': serviceId,
          'trigger_type': triggerType,
          'payer_type': payerType,
        });
      }
    }
  }

  /// Rozdělí jméno na first_name a last_name (první slovo / zbytek).
  static (String, String) _splitName(String name) {
    final t = name.trim();
    if (t.isEmpty) return ('', '');
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts[0], '');
    return (parts.first, parts.sublist(1).join(' '));
  }

  /// Normalizuje roli personálu na platné hodnoty: admin, worker.
  static String _normalizeStaffRole(String role) {
    final r = role.trim().toLowerCase();
    if (r == 'admin' || r.contains('admin') || r == 'manažer') return 'admin';
    return 'worker';
  }
}
