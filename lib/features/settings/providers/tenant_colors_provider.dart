import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/theme/app_palette_defaults.dart';
import 'package:falconest/core/theme/app_theme.dart';
import 'package:falconest/features/settings/repositories/tenant_ui_preferences_repository.dart';

/// Injekce [TenantUiPreferencesRepository] – Drift + Supabase na jednom místě pro feature Nastavení.
///
/// PROČ: Repozitář nepatří do [database_provider] (ten drží čistě Drift tasky); brandové barvy
/// jsou doménou nastavení a zůstávají vedle [tenantColorsProvider].
final tenantUiPreferencesRepositoryProvider =
    Provider<TenantUiPreferencesRepository>((ref) {
  return TenantUiPreferencesRepository(
    driftDb: ref.watch(driftDatabaseProvider),
  );
});

/// Lokální stav brandových barev (HEX řetězce jak je drží Drift / Supabase).
///
/// PROČ: Oddělený immutable stav od [TenantUiPreference] (Drift entita), aby provider nemusel
/// exponovat generované Drift typy do UI vrstvy.
@immutable
class TenantColorsState {
  const TenantColorsState({
    this.primaryHex,
    this.secondaryHex,
  });

  final String? primaryHex;
  final String? secondaryHex;

  /// Barva pro náhled / color picker – null HEX znamená výchozí FalcoNest.
  Color resolvedPrimaryColor() =>
      _decodeStorageHex(primaryHex) ?? AppPaletteDefaults.primary;

  Color resolvedSecondaryColor() =>
      _decodeStorageHex(secondaryHex) ?? AppPaletteDefaults.secondary;
}

/// Provider brandových barev tenanta: po přihlášení stáhne server ([syncFromServer]), pak čte Drift.
///
/// PROČ [AsyncNotifier]: první načtení je asynchronní (síť + SQLite); UI může zobrazit výchozí
/// barvy až do dokončení [build] bez pádu. Zápis přes [updatePrimaryColor] / [updateSecondaryColor]
/// nejdřív persistuje repozitář (Drift → pokus o Supabase), poté synchronně obnoví [state].
final tenantColorsProvider =
    AsyncNotifierProvider<TenantColorsNotifier, TenantColorsState>(
  TenantColorsNotifier.new,
);

class TenantColorsNotifier extends AsyncNotifier<TenantColorsState> {
  @override
  Future<TenantColorsState> build() async {
    // PROČ watch: změna tenanta (přepnutí agentury) musí znovu stáhnout správný řádek z DB.
    final tenantId =
        ref.watch(authNotifierProvider.select((n) => n.tenantIdForData))?.trim() ??
            '';
    if (tenantId.isEmpty) {
      return const TenantColorsState();
    }

    final repo = ref.read(tenantUiPreferencesRepositoryProvider);
    // PROČ sync před čtením: Timestamp Merging – pokud admin změnil barvy na webu, lokální SQLite
    // se před zobrazením v UI srovná se serverem (pokud je server novější).
    await repo.syncFromServer(tenantId);
    final local = await repo.getLocal(tenantId);
    return TenantColorsState(
      primaryHex: local?.primaryColor,
      secondaryHex: local?.secondaryColor,
    );
  }

  /// Uloží novou primární barvu (Drift ihned, Supabase na pozadí v try-catch v repozitáři).
  ///
  /// PROČ samostatná metoda: sekundární barva se musí zachovat – bereme aktuální z DB po zápisu,
  /// ne ze [state], aby nedošlo ke ztrátě při souběžných async přechodech.
  Future<void> updatePrimaryColor(Color color) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData?.trim() ?? '';
    if (tenantId.isEmpty) {
      return;
    }
    final repo = ref.read(tenantUiPreferencesRepositoryProvider);
    final before = await repo.getLocal(tenantId);
    await repo.savePreferences(
      tenantId: tenantId,
      primaryColor: _encodeStorageHex(color),
      secondaryColor: before?.secondaryColor,
    );
    final after = await repo.getLocal(tenantId);
    state = AsyncData(
      TenantColorsState(
        primaryHex: after?.primaryColor,
        secondaryHex: after?.secondaryColor,
      ),
    );
  }

  /// Uloží novou sekundární barvu; primární zůstává z aktuálního lokálního řádku.
  Future<void> updateSecondaryColor(Color color) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData?.trim() ?? '';
    if (tenantId.isEmpty) {
      return;
    }
    final repo = ref.read(tenantUiPreferencesRepositoryProvider);
    final before = await repo.getLocal(tenantId);
    await repo.savePreferences(
      tenantId: tenantId,
      primaryColor: before?.primaryColor,
      secondaryColor: _encodeStorageHex(color),
    );
    final after = await repo.getLocal(tenantId);
    state = AsyncData(
      TenantColorsState(
        primaryHex: after?.primaryColor,
        secondaryHex: after?.secondaryColor,
      ),
    );
  }

  /// Obnoví výchozí FalcoNest paletu (NULL v DB = aplikace použije [AppPaletteDefaults]).
  ///
  /// PROČ NULL místo mazání řádku: repozitář dělá update/insert s null sloupci; UNIQUE na tenant_id zůstane.
  Future<void> resetToDefaults() async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData?.trim() ?? '';
    if (tenantId.isEmpty) {
      return;
    }
    final repo = ref.read(tenantUiPreferencesRepositoryProvider);
    await repo.savePreferences(
      tenantId: tenantId,
      primaryColor: null,
      secondaryColor: null,
    );
    state = const AsyncData(TenantColorsState());
  }
}

/// Globální [ThemeData] z brandových barev tenanta + **statické** sémantické barvy z [CustomColors.light].
///
/// PROČ sleduje [tenantColorsProvider]: jakmile notifier po uložení aktualizuje stav, téma se přegeneruje
/// a celá aplikace okamžitě přejde na nové primary/secondary. Loading/error vede na výchozí brand barvy.
final appThemeFromTenantColorsProvider = Provider<ThemeData>((ref) {
  final async = ref.watch(tenantColorsProvider);
  return async.when(
    data: (s) => AppTheme.buildLightThemeForTenant(
      brandPrimary: s.resolvedPrimaryColor(),
      brandSecondary: s.resolvedSecondaryColor(),
    ),
    loading: () => AppTheme.buildLightThemeForTenant(),
    error: (Object error, StackTrace stackTrace) =>
        AppTheme.buildLightThemeForTenant(),
  );
});

String _encodeStorageHex(Color c) {
  final a = (c.a * 255.0).round().clamp(0, 255);
  final r = (c.r * 255.0).round().clamp(0, 255);
  final g = (c.g * 255.0).round().clamp(0, 255);
  final b = (c.b * 255.0).round().clamp(0, 255);
  final n = ((a << 24) | (r << 16) | (g << 8) | b) & 0xFFFFFFFF;
  return n.toRadixString(16).padLeft(8, '0');
}

Color? _decodeStorageHex(String? hex) {
  if (hex == null || hex.trim().isEmpty) {
    return null;
  }
  var s = hex.trim().toLowerCase();
  if (s.startsWith('#')) {
    s = s.substring(1);
  }
  if (s.length == 6) {
    s = 'ff$s';
  }
  if (s.length != 8) {
    return null;
  }
  final n = int.tryParse(s, radix: 16);
  if (n == null) {
    return null;
  }
  return Color(n);
}
