import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/features/super_admin/services/master_excel_parser.dart';
import 'package:falconest/features/super_admin/services/onboarding_db_service.dart';

/// Stav krokového průvodce White-Glove Onboarding.
///
/// Drží aktuální krok (0–2), stavy načítání a výsledky importu pro jednotlivé kroky.
/// [tenantId] = agentura, pro kterou se data importují (zabránění chybám při výběru).
class OnboardingWizardState {
  const OnboardingWizardState({
    this.tenantId,
    this.currentStep = 0,
    this.step1Loading = false,
    this.step2Loading = false,
    this.step3Loading = false,
    this.isImporting = false,
    this.parsedStaff,
    this.step1Error,
    this.parsedServices,
    this.step2Error,
    this.parsedApartments,
    this.step3Error,
  });

  /// Agentura, pro kterou wizard běží – nastaví se při otevření z TenantDetailScreen.
  final String? tenantId;

  /// Aktuální krok (0 = Interní tým, 1 = Katalog služeb, 2 = Portfolio).
  final int currentStep;

  /// Krok 1: Načítá se Excel (personál).
  final bool step1Loading;

  /// Krok 2: Načítá se Excel (ceník služeb).
  final bool step2Loading;

  /// Krok 3: Načítá se Excel (apartmány a majitelé).
  final bool step3Loading;

  /// Probíhá finální import dat do databáze (tlačítko Spustit import).
  final bool isImporting;

  /// Výsledek parsování Kroku 1 – personál z listu 01_Personal.
  final List<ParsedStaff>? parsedStaff;

  /// Chyba při parsování Kroku 1.
  final String? step1Error;

  /// Výsledek parsování Kroku 2 – služby z listu 02_Katalog_Sluzeb.
  final List<ParsedService>? parsedServices;

  /// Chyba při parsování Kroku 2.
  final String? step2Error;

  /// Výsledek parsování Kroku 3 – apartmány z listu 03_Portfolio.
  final List<ParsedApartment>? parsedApartments;

  /// Chyba při parsování Kroku 3.
  final String? step3Error;

  /// True, pokud jsou všechna tři kroky úspěšně naparsována (lze spustit import).
  bool get canRunImport =>
      (parsedStaff != null && parsedStaff!.isNotEmpty) &&
      (parsedServices != null && parsedServices!.isNotEmpty) &&
      (parsedApartments != null && parsedApartments!.isNotEmpty);

  OnboardingWizardState copyWith({
    String? tenantId,
    int? currentStep,
    bool? step1Loading,
    bool? step2Loading,
    bool? step3Loading,
    bool? isImporting,
    List<ParsedStaff>? parsedStaff,
    String? step1Error,
    bool clearStep1Error = false,
    List<ParsedService>? parsedServices,
    String? step2Error,
    bool clearStep2Error = false,
    List<ParsedApartment>? parsedApartments,
    String? step3Error,
    bool clearStep3Error = false,
  }) {
    return OnboardingWizardState(
      tenantId: tenantId ?? this.tenantId,
      currentStep: currentStep ?? this.currentStep,
      step1Loading: step1Loading ?? this.step1Loading,
      step2Loading: step2Loading ?? this.step2Loading,
      step3Loading: step3Loading ?? this.step3Loading,
      isImporting: isImporting ?? this.isImporting,
      parsedStaff: parsedStaff ?? this.parsedStaff,
      step1Error: clearStep1Error ? null : (step1Error ?? this.step1Error),
      parsedServices: parsedServices ?? this.parsedServices,
      step2Error: clearStep2Error ? null : (step2Error ?? this.step2Error),
      parsedApartments: parsedApartments ?? this.parsedApartments,
      step3Error: clearStep3Error ? null : (step3Error ?? this.step3Error),
    );
  }
}

/// Notifier pro White-Glove Onboarding Wizard.
///
/// Řídí průchod kroky a stavy načítání. Zatím bez implementace skutečného
/// importu – pouze UI placeholder. Při budoucím rozšíření zde bude logika
/// volání služeb pro parsování a zápis dat z Master Excelu.
class OnboardingWizardNotifier extends Notifier<OnboardingWizardState> {
  @override
  OnboardingWizardState build() => const OnboardingWizardState();

  /// Nastaví aktuální krok (0–2).
  void setStep(int step) {
    final clamped = step.clamp(0, 2);
    state = state.copyWith(currentStep: clamped);
  }

  /// Krok vpřed (max. 2).
  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  /// Krok zpět (min. 0).
  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  /// Nastaví tenantId – voláno při otevření wizardu z TenantDetailScreen.
  /// Při přepnutí na jinou agenturu resetuje stav, aby nedošlo k záměně dat.
  void setTenantId(String tenantId) {
    if (state.tenantId != tenantId) {
      state = OnboardingWizardState(tenantId: tenantId);
    }
  }

  /// Zpracuje nahraný Excel pro Krok 1 (Personál).
  ///
  /// Volající (onboarding_wizard_screen) získá bytes z FilePicker a předá je sem.
  /// Parser přečte list 01_Personal a uloží výsledek do [parsedStaff].
  /// Při chybě uloží hlášku do [step1Error] – UI ji zobrazí uživateli.
  Future<void> handleStep1Upload(List<int> bytes) async {
    state = state.copyWith(step1Loading: true, clearStep1Error: true);
    try {
      final staff = MasterExcelParser.parseStaffSheet(bytes);
      state = state.copyWith(
        step1Loading: false,
        parsedStaff: staff,
        clearStep1Error: true,
      );
    } catch (e) {
      final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
      state = state.copyWith(
        step1Loading: false,
        step1Error: msg,
      );
    }
  }

  /// Zpracuje nahraný Excel pro Krok 2 (Katalog služeb).
  Future<void> handleStep2Upload(List<int> bytes) async {
    state = state.copyWith(step2Loading: true, clearStep2Error: true);
    try {
      final services = MasterExcelParser.parseServicesSheet(bytes);
      state = state.copyWith(
        step2Loading: false,
        parsedServices: services,
        clearStep2Error: true,
      );
    } catch (e) {
      final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
      state = state.copyWith(
        step2Loading: false,
        step2Error: msg,
      );
    }
  }

  /// Zpracuje nahraný Excel pro Krok 3 (Portfolio).
  Future<void> handleStep3Upload(List<int> bytes) async {
    state = state.copyWith(step3Loading: true, clearStep3Error: true);
    try {
      final apartments = MasterExcelParser.parsePortfolioSheet(bytes);
      state = state.copyWith(
        step3Loading: false,
        parsedApartments: apartments,
        clearStep3Error: true,
      );
    } catch (e) {
      final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
      state = state.copyWith(
        step3Loading: false,
        step3Error: msg,
      );
    }
  }

  /// Provede finální import naparsovaných dat do databáze.
  ///
  /// Volá [OnboardingDbService.importTenantData] a podle výsledku zobrazí
  /// Snackbar a případně přesměruje na detail tenanta. [context] potřebný pro
  /// ScaffoldMessenger a GoRouter – předává se z UI (onboarding_wizard_screen).
  Future<void> runImport(BuildContext context) async {
    if (!state.canRunImport || state.tenantId == null) return;
    state = state.copyWith(isImporting: true);
    try {
      await OnboardingDbService.importTenantData(
        tenantId: state.tenantId!,
        staff: state.parsedStaff!,
        services: state.parsedServices!,
        apartments: state.parsedApartments!,
      );
      state = state.copyWith(isImporting: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('super_admin.onboarding_wizard_import_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/super-admin/tenant/${state.tenantId}');
      }
    } catch (e) {
      state = state.copyWith(isImporting: false);
      if (context.mounted) {
        final msg = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'super_admin.onboarding_wizard_import_error'.tr(namedArgs: {'error': msg}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Provider pro Onboarding Wizard – dostupný v rámci Super Admin modulu.
final onboardingWizardProvider =
    NotifierProvider<OnboardingWizardNotifier, OnboardingWizardState>(
  OnboardingWizardNotifier.new,
);
