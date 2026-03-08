import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/utils/read_file_bytes/read_file_bytes.dart';
import 'package:falconest/features/super_admin/providers/onboarding_wizard_provider.dart';
import 'package:falconest/features/super_admin/services/master_excel_parser.dart';

/// Obrazovka White-Glove Onboarding Wizard – krokový průvodce pro import nové agentury.
///
/// Slouží pro prémiové zakládání agentur nahráváním záložek z Master Excelu.
/// Vyžaduje [tenantId] – wizard patří konkrétní agentuře, aby se zabránilo chybám při importu.
///
/// PROČ Stepper: Material Design komponenta pro krokové formuláře – uživatel
/// vidí postup a může se vracet mezi kroky.
class SuperAdminOnboardingWizardScreen extends ConsumerStatefulWidget {
  const SuperAdminOnboardingWizardScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  ConsumerState<SuperAdminOnboardingWizardScreen> createState() =>
      _SuperAdminOnboardingWizardScreenState();
}

class _SuperAdminOnboardingWizardScreenState
    extends ConsumerState<SuperAdminOnboardingWizardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingWizardProvider.notifier).setTenantId(widget.tenantId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingWizardProvider);
    final notifier = ref.read(onboardingWizardProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/super-admin/tenant/${widget.tenantId}'),
          tooltip: 'common.back'.tr(),
        ),
        title: Text('super_admin.onboarding_wizard_title'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Stepper(
          currentStep: state.currentStep,
          onStepContinue: () {
            if (state.currentStep < 2) {
              notifier.nextStep();
            }
          },
          onStepCancel: () {
            if (state.currentStep > 0) {
              notifier.previousStep();
            }
          },
          onStepTapped: (index) => notifier.setStep(index),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: state.currentStep < 2
                        ? Text('super_admin.onboarding_wizard_next'.tr())
                        : Text('super_admin.onboarding_wizard_finish'.tr()),
                  ),
                  if (state.currentStep > 0) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: Text('super_admin.onboarding_wizard_back'.tr()),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            _buildStep1(context, ref, state, notifier, widget.tenantId),
            _buildStep2(context, ref, state, notifier, widget.tenantId),
            _buildStep3(context, ref, state, notifier, widget.tenantId),
          ],
        ),
      ),
    );
  }

  /// Krok 1: Interní Tým (Personál) – administrátoři a pracovníci.
  static Step _buildStep1(
    BuildContext context,
    WidgetRef ref,
    OnboardingWizardState state,
    OnboardingWizardNotifier notifier,
    String tenantId,
  ) {
    final isLoading = state.step1Loading;
    return Step(
      title: Text('super_admin.onboarding_wizard_step1_title'.tr()),
      subtitle: Text('super_admin.onboarding_wizard_step1_subtitle'.tr()),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'super_admin.onboarding_wizard_step1_description'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => _pickExcelAndProcess(context, notifier.handleStep1Upload),
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text('super_admin.onboarding_wizard_upload_excel'.tr()),
          ),
          if (state.step1Error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                state.step1Error!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 16),
          state.parsedStaff != null && state.parsedStaff!.isNotEmpty
              ? _StaffResultList(staff: state.parsedStaff!)
              : _ResultPlaceholder(
                  label: 'super_admin.onboarding_wizard_result_placeholder'.tr(),
                ),
        ],
      ),
      isActive: state.currentStep >= 0,
      state: state.currentStep > 0 ? StepState.complete : StepState.indexed,
    );
  }

  /// Krok 2: Katalog Služeb – ceník a typy služeb.
  static Step _buildStep2(
    BuildContext context,
    WidgetRef ref,
    OnboardingWizardState state,
    OnboardingWizardNotifier notifier,
    String tenantId,
  ) {
    final isLoading = state.step2Loading;
    return Step(
      title: Text('super_admin.onboarding_wizard_step2_title'.tr()),
      subtitle: Text('super_admin.onboarding_wizard_step2_subtitle'.tr()),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'super_admin.onboarding_wizard_step2_description'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => _pickExcelAndProcess(context, notifier.handleStep2Upload),
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text('super_admin.onboarding_wizard_upload_excel'.tr()),
          ),
          if (state.step2Error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                state.step2Error!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 16),
          state.parsedServices != null && state.parsedServices!.isNotEmpty
              ? _ServiceResultList(services: state.parsedServices!)
              : _ResultPlaceholder(
                  label: 'super_admin.onboarding_wizard_result_placeholder'.tr(),
                ),
        ],
      ),
      isActive: state.currentStep >= 1,
      state: state.currentStep > 1 ? StepState.complete : StepState.indexed,
    );
  }

  /// Krok 3: Portfolio – majitelé a apartmány.
  static Step _buildStep3(
    BuildContext context,
    WidgetRef ref,
    OnboardingWizardState state,
    OnboardingWizardNotifier notifier,
    String tenantId,
  ) {
    final isLoading = state.step3Loading;
    return Step(
      title: Text('super_admin.onboarding_wizard_step3_title'.tr()),
      subtitle: Text('super_admin.onboarding_wizard_step3_subtitle'.tr()),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'super_admin.onboarding_wizard_step3_description'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => _pickExcelAndProcess(context, notifier.handleStep3Upload),
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text('super_admin.onboarding_wizard_upload_excel'.tr()),
          ),
          if (state.step3Error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                state.step3Error!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 16),
          state.parsedApartments != null && state.parsedApartments!.isNotEmpty
              ? _ApartmentResultList(apartments: state.parsedApartments!)
              : _ResultPlaceholder(
                  label: 'super_admin.onboarding_wizard_result_placeholder'.tr(),
                ),
          if (state.currentStep == 2 && state.canRunImport) ...[
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: state.isImporting ? null : () => notifier.runImport(context),
              icon: state.isImporting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.cloud_upload, size: 24),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  state.isImporting
                      ? 'super_admin.onboarding_wizard_importing'.tr()
                      : 'super_admin.onboarding_wizard_run_import'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
      isActive: state.currentStep >= 2,
      state: StepState.indexed,
    );
  }

  /// Otevře FilePicker, načte bajty souboru a předá je do [onUpload].
  /// Pro Krok 1 volá [handleStep1Upload] s reálným parsováním; Kroky 2 a 3 zatím simulují.
  static Future<void> _pickExcelAndProcess(
    BuildContext context,
    Future<void> Function(List<int> bytes) onUpload,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    List<int> bytes = result.files.single.bytes?.toList() ?? [];
    if (bytes.isEmpty && result.files.single.path != null) {
      bytes = await readFileBytes(result.files.single.path!);
    }
    if (bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('super_admin.onboarding_wizard_empty_file'.tr())),
        );
      }
      return;
    }

    await onUpload(bytes);
  }
}

/// Seznam načtených apartmánů z Kroku 3 – tabulkový přehled.
class _ApartmentResultList extends StatelessWidget {
  const _ApartmentResultList({required this.apartments});

  final List<ParsedApartment> apartments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.apartment, color: Colors.purple.shade700, size: 28),
              const SizedBox(width: 12),
              Text(
                'super_admin.onboarding_wizard_apartments_count'.tr(namedArgs: {'count': '${apartments.length}'}),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...apartments.take(10).map(
                (a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${a.apartmentCode} · ${a.name} · ${a.ownerName} · ${'super_admin.onboarding_wizard_apartment_services'.tr(namedArgs: {'count': '${a.activeServices.length}'})}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
              ),
          if (apartments.length > 10)
            Text(
              'super_admin.onboarding_wizard_apartments_more'.tr(namedArgs: {'count': '${apartments.length - 10}'}),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

/// Seznam načtených služeb z Kroku 2 – tabulkový přehled.
class _ServiceResultList extends StatelessWidget {
  const _ServiceResultList({required this.services});

  final List<ParsedService> services;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              Text(
                'super_admin.onboarding_wizard_services_count'.tr(namedArgs: {'count': '${services.length}'}),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...services.take(10).map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${s.serviceCode} · ${s.name} · ${s.priceEur.toStringAsFixed(2)} € · ${s.payer}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
              ),
          if (services.length > 10)
            Text(
              'super_admin.onboarding_wizard_services_more'.tr(namedArgs: {'count': '${services.length - 10}'}),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

/// Seznam načteného personálu z Kroku 1 – tabulkový přehled.
class _StaffResultList extends StatelessWidget {
  const _StaffResultList({required this.staff});

  final List<ParsedStaff> staff;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.green.shade700, size: 28),
              const SizedBox(width: 12),
              Text(
                'super_admin.onboarding_wizard_staff_count'.tr(namedArgs: {'count': '${staff.length}'}),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...staff.take(10).map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${s.name} · ${s.email} · ${s.role}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
              ),
          if (staff.length > 10)
            Text(
              'super_admin.onboarding_wizard_staff_more'.tr(namedArgs: {'count': '${staff.length - 10}'}),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

/// Maketa pro zobrazení výsledku importu – šedý box s nápisem.
///
/// Při budoucím rozšíření sem přijde skutečný report (počet řádků, chyby).
class _ResultPlaceholder extends StatelessWidget {
  const _ResultPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart_outlined, size: 40, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
