part of 'package:falconest/features/admin/admin_tasks_screen.dart';

/// Dialog pro přidání nového úkolu.
///
/// [initialApartmentId] a [initialReservationId] – volitelné při vytváření úkolu z rezervace
/// (sekce Související úkoly). Předvyberou apartmán a provážou úkol s rezervací v DB.
/// [initialReservationInfo] – text hosta a termínu pro kontextový pruh (např. "Káťa (4.3. - 11.3.2026)").
/// [initialClientId] – předvybrání klienta u externí služby (z kontextu Detailu klienta).
class _AddTaskDialog extends ConsumerStatefulWidget {
  const _AddTaskDialog({
    required this.ref,
    required this.onSaved,
    this.initialApartmentId,
    this.initialReservationId,
    this.initialReservationInfo,
    this.initialClientId,
    this.aiPrefill,
  });

  final WidgetRef ref;
  final VoidCallback onSaved;

  /// Při vytvoření z rezervace – předvybrání apartmánu.
  final String? initialApartmentId;

  /// Při vytvoření z rezervace – provázání úkolu s rezervací (reservation_id v payloadu).
  final String? initialReservationId;

  /// Při vytvoření z rezervace – text pro kontextový pruh (host + termín).
  final String? initialReservationInfo;

  /// Z kontextu Detailu klienta – předvybrání klienta u externí služby.
  final String? initialClientId;

  /// Návrh z AI parsování WhatsApp textu – pouze předvyplnění, ukládá dispečer ručně.
  final TaskFormDraft? aiPrefill;

  @override
  ConsumerState<_AddTaskDialog> createState() => _AddTaskDialogState();
}

/// Kontextový pruh v dialogu přidání úkolu – apartmán a rezervace (při vytváření z rezervace).
class _AddTaskContextBar extends StatelessWidget {
  const _AddTaskContextBar({
    required this.apartmentsAsync,
    required this.selectedApartmentId,
    required this.taskMode,
    this.initialReservationInfo,
  });

  final AsyncValue<List<ApartmentRow>> apartmentsAsync;
  final String? selectedApartmentId;
  final _TaskFormMode taskMode;
  final String? initialReservationInfo;

  @override
  Widget build(BuildContext context) {
    final hasApartment =
        taskMode == _TaskFormMode.apartmentBound &&
        selectedApartmentId != null &&
        selectedApartmentId!.isNotEmpty;
    final reservationInfoText = initialReservationInfo?.trim();
    final hasReservation =
        reservationInfoText != null && reservationInfoText.isNotEmpty;

    if (!hasApartment && !hasReservation) return const SizedBox.shrink();

    String? apartmentName;
    if (hasApartment) {
      final apartments = apartmentsAsync.valueOrNull ?? [];
      apartmentName = apartments
          .where((a) => a.id == selectedApartmentId)
          .firstOrNull
          ?.name;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasApartment && apartmentName != null && apartmentName.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.apartment_outlined,
                  size: 16,
                  color: context.colors.onSurfaceVariant,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'admin.task_context_apartment'.tr(
                      namedArgs: {'name': apartmentName},
                    ),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          if (hasApartment && hasReservation) SizedBox(height: AppSpacing.sm),
          if (hasReservation)
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: context.colors.onSurfaceVariant,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'admin.task_context_reservation'.tr(
                      namedArgs: {'guest': reservationInfoText},
                    ),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Modul v Supabase Storage pro přílohy úkolů – konzistence s mobilní aplikací.
const _storageModuleTasks = 'tasks';

/// Wrapper pro Rychlý výběr adres – odvozuje addressSourceClientId z vybraného klienta.
///
/// PROČ: Agency = vlastní adresy; external s agencyId = adresy agentury; external bez agencyId =
/// nezobrazit. Potřebujeme clientsFullListProvider pro výpočet, proto oddělený widget. Používá se
/// v Add i Edit Task dialogu.
class _TaskAddressQuickSelectWrapper extends ConsumerWidget {
  const _TaskAddressQuickSelectWrapper({
    required this.selectedClientId,
    required this.controller,
    this.onFilled,
    this.enabled = true,
  });

  final String? selectedClientId;
  final TextEditingController controller;
  final VoidCallback? onFilled;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedClientId == null || selectedClientId!.isEmpty) {
      return const SizedBox.shrink();
    }
    final clientsAsync = ref.watch(clientsFullListProvider);
    return clientsAsync.when(
      data: (clients) {
        final client = clients
            .where((c) => c.id == selectedClientId)
            .firstOrNull;
        final addressSourceId = _addressSourceClientId(client);
        if (addressSourceId == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ClientAddressQuickSelect(
              addressSourceClientId: addressSourceId,
              controller: controller,
              onFilled: onFilled,
              enabled: enabled,
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Vrací ID klienta, ze kterého načíst adresy pro Rychlý výběr.
///
/// PROČ: Agency má vlastní adresy; external s agencyId „půjčuje si“ adresy své
/// doporučující agentury (Pepa dohodnutý Davidem → Davidovy adresy).
String? _addressSourceClientId(ClientModel? client) {
  if (client == null) return null;
  final t = client.clientType?.toLowerCase() ?? '';
  if (t == 'agency') return client.id;
  if (t == 'external' &&
      client.agencyId != null &&
      client.agencyId!.trim().isNotEmpty) {
    return client.agencyId;
  }
  return null;
}

/// Rychlý výběr adres z adresáře klienta – zobrazí se nad polem pro vlastní adresu.
///
/// PROČ: U ručních externích úkolů (bez bytu) má klient často uložené adresy v Adresáři.
/// [addressSourceClientId] = ID klienta, jehož adresy se zobrazí. U agency je to
/// sám klient; u external s agencyId je to jeho doporučující agentura.
class _ClientAddressQuickSelect extends ConsumerWidget {
  const _ClientAddressQuickSelect({
    required this.addressSourceClientId,
    required this.controller,
    this.onFilled,
    this.enabled = true,
  });

  final String addressSourceClientId;
  final TextEditingController controller;
  final VoidCallback? onFilled;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(
      clientAddressesProvider(addressSourceClientId),
    );
    return addressesAsync.when(
      data: (addresses) {
        if (addresses.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'tasks.form_quick_address_select'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 6,
              children: addresses.map((addr) {
                return ActionChip(
                  label: Text(addr.label),
                  onPressed: enabled
                      ? () {
                          controller.text = addr.address;
                          controller.selection = TextSelection.collapsed(
                            offset: controller.text.length,
                          );
                          onFilled?.call();
                        }
                      : null,
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Typ úkolu: vázáno na apartmán (výchozí) nebo externí služba bez bytu.
enum _TaskFormMode { apartmentBound, externalService }

/// Varovný pruh po AI prefill – upozorní dispečera na nejisté párování apartmánu.
class _AiPrefillHintBanner extends StatelessWidget {
  const _AiPrefillHintBanner({required this.draft});

  final TaskFormDraft draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.customColors.warningSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.customColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: context.customColors.warning,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              draft.hasLowConfidenceApartmentMatch
                  ? 'admin.task_draft_form_review_apartment'.tr()
                  : 'admin.task_draft_form_review_generic'.tr(),
              style: context.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTaskDialogState extends ConsumerState<_AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Plánovaný začátek okna úkolu – výchozí „teď“ aby šlo hned uložit bez prázdného termínu.
  final _scheduledStartController = TextEditingController(
    text: _formatDateTime(DateTime.now()),
  );

  /// Trvání v minutách – spolu se začátkem určuje `due_date` v DB.
  final _durationMinutesController = TextEditingController(text: '60');

  /// Pro externí službu: adresa/lokace (custom_location).
  final _customLocationController = TextEditingController();

  /// Jedno pole GPS pro externí lokaci (`tasks.geo_location`) – paste z map.
  final _externalGpsController = TextEditingController();

  /// Pro externí službu – cena v EUR při „Vybere personál v hotovosti“.
  final _priceController = TextEditingController();

  /// Historical pricing: Cena služby u úkolu vázaného na apartmán – zamrazí se do metadata['service_price'].
  /// Auto-fill z apartment_services při výběru bytu a služby; dispečer může přepsat.
  final _servicePriceController = TextEditingController();

  /// Číslo letu pro transfery – uloží se do metadata['flight_number'], zobrazí jen při transfer_in/out/transfer.
  final _flightNumberController = TextEditingController();
  _TaskFormMode _taskMode = _TaskFormMode.apartmentBound;
  String? _selectedApartmentId;
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    // Při vytvoření z rezervace: předvyber apartmán a typ "Vázáno na apartmán".
    if (widget.initialApartmentId != null &&
        widget.initialApartmentId!.isNotEmpty) {
      _taskMode = _TaskFormMode.apartmentBound;
      _selectedApartmentId = widget.initialApartmentId;
    }
    // Z kontextu Detailu klienta (externí/agency): předvyber klienta a typ "Externí služba".
    if (widget.initialClientId != null && widget.initialClientId!.isNotEmpty) {
      _taskMode = _TaskFormMode.externalService;
      _selectedClientId = widget.initialClientId;
    }
    // AI prefill až po prvním frame – controllery a setState jsou připravené.
    if (widget.aiPrefill != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyAiPrefill(widget.aiPrefill!);
      });
    }
  }

  /// Aplikuje [TaskFormDraft] do lokálního stavu formuláře – neukládá do DB.
  ///
  /// PROČ post-frame: [manualTaskServicePriceProvider] listener reaguje na apartmán/službu;
  /// controllery musí být nastaveny v jednom setState cyklu. WhatsApp cena má přednost
  /// před katalogem – proto [_aiOverridePrice] + dodatečný delay přepisu.
  void _applyAiPrefill(TaskFormDraft draft) {
    setState(() {
      switch (draft.taskMode) {
        case TaskFormDraftMode.apartmentBound:
          _taskMode = _TaskFormMode.apartmentBound;
          break;
        case TaskFormDraftMode.externalService:
          _taskMode = _TaskFormMode.externalService;
          break;
        case TaskFormDraftMode.unknown:
          break;
      }

      final title = draft.title?.trim();
      if (title != null && title.isNotEmpty) {
        _titleController.text = title;
      }

      final desc = draft.description?.trim();
      if (desc != null && desc.isNotEmpty) {
        _descriptionController.text = desc;
      }

      if (draft.scheduledStart != null) {
        // Wall-clock z AI (11:15) – nikdy nevolat toLocal() na UTC (posun +1/+2h).
        final dt = draft.scheduledStart!;
        final wall = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
        _scheduledStartController.text = _formatDateTime(wall);
      }

      if (draft.durationMinutes != null && draft.durationMinutes! > 0) {
        _durationMinutesController.text = '${draft.durationMinutes}';
      }

      final aptId = draft.apartmentId?.trim();
      if (aptId != null && aptId.isNotEmpty) {
        _selectedApartmentId = aptId;
      }

      final clientId = draft.clientId?.trim();
      if (clientId != null && clientId.isNotEmpty) {
        _selectedClientId = clientId;
      }

      // PROČ: Bez spárovaného serviceId nesmíme auto-vybrat první položku katalogu
      // (typicky „Základní úklid“) – u transferů/letiště by to bylo špatně.
      final serviceId = draft.serviceId?.trim();
      if (serviceId != null && serviceId.isNotEmpty) {
        _selectedServiceId = serviceId;
      } else {
        _selectedServiceId = null;
      }

      final loc = draft.customLocationHint?.trim();
      if (loc != null && loc.isNotEmpty) {
        _customLocationController.text = loc;
      }

      if (draft.isCashPayment != null) {
        _staffCollectsCash = draft.isCashPayment!;
      }

      if (draft.price != null && draft.price! > 0) {
        _aiOverridePrice = draft.price;
        final formatted = draft.price!.toStringAsFixed(2);
        _priceController.text = formatted;
        _servicePriceController.text = formatted;
      }
    });

    // Katalogový listener může doběhnout až po setState – WhatsApp cena přepíše default.
    if (draft.price != null && draft.price! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          final formatted = draft.price!.toStringAsFixed(2);
          setState(() {
            _aiOverridePrice = draft.price;
            _priceController.text = formatted;
            _servicePriceController.text = formatted;
          });
        });
      });
    }
  }

  String? _selectedAssignedTo;

  /// Další přiřazení pracovníci (assigned_user_ids) – pro sdílení úkolu mezi více lidmi.
  List<String> _selectedAdditionalUserIds = [];

  /// ID vybrané služby z katalogu. PROČ: Umožňuje odvodit task_type a requires_photo.
  String? _selectedServiceId;

  /// Způsob platby u externí služby: true = vybere personál v hotovosti, false = faktura/zaplaceno předem.
  bool _staffCollectsCash = false;

  /// Cena z AI/WhatsApp – má přednost před auto-fillem z [manualTaskServicePriceProvider].
  double? _aiOverridePrice;
  String _status = _systemStatuses.first;
  bool _isSaving = false;
  /// Probíhá geokódování textu lokace (externí úkol) přes Nominatim.
  bool _isGeocodingExternal = false;

  /// Nově vybrané soubory k nahrání – bytes z file_picker (withData: true).
  List<PlatformFile> _pendingAttachments = [];

  /// Volitelná šablona checklistu – po uložení se zkopíruje do instance úkolu (null = bez checklistu).
  String? _selectedChecklistTemplateId;

  /// Ruční překlady titulku pro PDF (`title_i18n`); po potvrzení dialogu se pošlou v INSERTu (blokuje přepsání snapshotem z katalogu i když je mapa prázdná).
  Map<String, dynamic>? _titleI18nDraft;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _scheduledStartController.dispose();
    _durationMinutesController.dispose();
    _customLocationController.dispose();
    _externalGpsController.dispose();
    _priceController.dispose();
    _servicePriceController.dispose();
    _flightNumberController.dispose();
    super.dispose();
  }

  /// Doplní GPS z pole lokace (custom_location) u nového externího úkolu.
  Future<void> _fetchGpsFromExternalLocation() async {
    final addr = _customLocationController.text.trim();
    if (addr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_no_address'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isGeocodingExternal = true);
    try {
      final ll = await GeocodingService().getCoordinatesFromAddress(addr);
      if (!mounted) return;
      if (ll == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_no_result'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _externalGpsController.text = '${ll.latitude}, ${ll.longitude}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_success'.tr()),
            backgroundColor: context.customColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_error'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeocodingExternal = false);
    }
  }

  /// Otevře file_picker pro výběr přílohy (obrázek nebo PDF). withData: true získá bytes pro upload na web.
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final valid = result.files
          .where((f) => f.bytes != null && f.name.isNotEmpty)
          .toList();
      if (valid.isNotEmpty) {
        setState(
          () => _pendingAttachments = [..._pendingAttachments, ...valid],
        );
      }
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final isExternal = _taskMode == _TaskFormMode.externalService;
    if (!isExternal &&
        (_selectedApartmentId == null || _selectedApartmentId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_apartment_required_short'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (isExternal &&
        (_selectedClientId == null || _selectedClientId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_client_required'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (isExternal && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('tasks.validation_service_name_required'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final scheduledStart = _parseDateTime(
      _scheduledStartController.text.trim(),
    );
    if (scheduledStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_datetime_required_short'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final durationMinutes = int.tryParse(
      _durationMinutesController.text.trim(),
    );
    if (durationMinutes == null || durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_duration_minutes_positive'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final dueDate = scheduledStart.add(Duration(minutes: durationMinutes));
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: context.colors.error,
          ),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    try {
      final catalog = ref.read(tenantServicesProvider).valueOrNull ?? [];
      TenantServiceModel? service;
      if (_selectedServiceId != null && catalog.isNotEmpty) {
        try {
          service = catalog.firstWhere((s) => s.id == _selectedServiceId);
        } catch (e, st) {
          AppLogger.error('admin_tasks_screen: služba podle _selectedServiceId v katalogu nenalezena (vytvoření úkolu)', e, st);
        }
      }
      final taskType = service?.serviceType ?? 'extra';
      final metadata = <String, dynamic>{};
      if (service?.requiresPhoto == true) metadata['requires_photo'] = true;
      // PROČ: Jednotný odhad pro reporty a mobilní odpočet – musí odpovídat skutečnému intervalu v DB.
      metadata['estimated_minutes'] = durationMinutes;

      // PROČ: Externí služba – hotovost u personálu (amount_to_collect) + vždy service_price pro fakturaci.
      if (isExternal) {
        final priceStr = _priceController.text.trim();
        final price = double.tryParse(priceStr);
        // Zápis manuálně zadané ceny pro externí službu do metadat kvůli fakturaci.
        if (price != null && price > 0) {
          metadata['service_price'] = price;
          if (_staffCollectsCash) {
            metadata['amount_to_collect'] = price;
          }
        }
      }

      // Historical pricing: Manuální úkol vázaný na apartmán – zamražení ceny v okamžiku vytvoření.
      // Reporty a fakturace čtou metadata['service_price']; změna ceníku pak nezmění historický obrat.
      if (!isExternal) {
        final priceStr = _servicePriceController.text.trim();
        final servicePrice = double.tryParse(priceStr);
        if (servicePrice != null && servicePrice > 0) {
          metadata['service_price'] = servicePrice;
        }
      }

      // PROČ: Číslo letu pro transfery – řidič v mobilní aplikaci získá proklik na FlightRadar24.
      if (_isTransferTaskType(taskType)) {
        final fn = _flightNumberController.text.trim();
        if (fn.isNotEmpty) metadata['flight_number'] = fn;
      }

      // KROK 3 OPRAVA: Explicitní payer_type – úkol nese 100 % finančních dat (viz AUDIT_TASK_FINANCE_LIFECYCLE).
      if (isExternal) {
        metadata['payer_type'] = _staffCollectsCash ? 'guest' : 'client';
      } else {
        metadata['payer_type'] = 'owner';
      }

      final assignedToUuid =
          _selectedAssignedTo != null && _selectedAssignedTo!.isNotEmpty
          ? _selectedAssignedTo
          : null;
      final scheduledIso = scheduledStart.toUtc().toIso8601String();
      final dueIso = dueDate.toUtc().toIso8601String();
      final titleText = _titleController.text.trim();

      // KROK 1: Nahrání příloh na Supabase Storage (bytes z file_picker).
      List<String> mediaUrls = [];
      for (final file in _pendingAttachments) {
        if (file.bytes == null || file.bytes!.isEmpty) continue;
        try {
          final url = await MediaService.instance.uploadMediaBytes(
            file.bytes!,
            fileName: file.name,
            tenantId: tenantId,
            moduleName: _storageModuleTasks,
          );
          if (url != null && url.isNotEmpty) mediaUrls.add(url);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'common.generic_error_user_friendly'.tr(),
                ),
                backgroundColor: context.colors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      final payload = <String, dynamic>{
        'tenant_id': tenantId,
        'apartment_id': isExternal ? null : _selectedApartmentId,
        if (!isExternal &&
            widget.initialReservationId != null &&
            widget.initialReservationId!.isNotEmpty)
          'reservation_id': widget.initialReservationId,
        if (isExternal && _selectedClientId != null)
          'client_id': _selectedClientId,
        if (isExternal) 'custom_title': titleText,
        if (isExternal)
          'custom_location': _customLocationController.text.trim(),
        'assigned_to': assignedToUuid,
        if (_selectedAdditionalUserIds.isNotEmpty)
          'assigned_user_ids': _selectedAdditionalUserIds,
        'title': titleText,
        'description': _descriptionController.text.trim(),
        'status': _status,
        'task_type': taskType,
        'due_date': dueIso,
        'scheduled_start': scheduledIso,
        if (service != null) 'service_id': service.id,
        'metadata': metadata,
        if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
        if (_titleI18nDraft != null) 'title_i18n': _titleI18nDraft,
      };
      if (isExternal) {
        final g = GeoJsonPoint.tryParseSmartGpsText(_externalGpsController.text);
        payload['geo_location'] = GeoJsonPoint.toPostgrestJson(
          g?.latitude,
          g?.longitude,
        );
      }
      await ref
          .read(adminTasksProvider.notifier)
          .insertTaskInAdmin(
            payload,
            checklistTemplateId: _selectedChecklistTemplateId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.task_saved'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('task save Postgrest: ${e.message} (code ${e.code})');
        if (e.code == '42703' || e.message.contains('column')) {
          debugPrint(
            '--- CHYBÍ SLOUPCE V TABULCE tasks. Spusť v Supabase SQL Editor příkazy z admin_tasks_provider.dart (_buildAlterTableSql).',
          );
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _postgrestSnackMessage(e),
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    // Dostupný personál v den úkolu (smlouva + schválené absence) – stejná logika jako automatický generátor.
    final taskDate =
        _parseDateTime(_scheduledStartController.text.trim()) ?? DateTime.now();
    final teamAsync = ref.watch(availableTeamForTaskProvider(taskDate));
    final catalogAsync = ref.watch(tenantServicesProvider);

    // Historical pricing – auto-fill ceny při výběru bytu a služby. Provider reaguje na oba parametry.
    // PROČ: WhatsApp/AI cena (_aiOverridePrice) má přednost před katalogem.
    ref.listen(
      manualTaskServicePriceProvider((
        _selectedApartmentId ?? '',
        _selectedServiceId ?? '',
      )),
      (prev, next) {
        next.whenData((price) {
          if (!mounted) return;
          if (_aiOverridePrice != null && _aiOverridePrice! > 0) {
            final formatted = _aiOverridePrice!.toStringAsFixed(2);
            _servicePriceController.text = formatted;
            _priceController.text = formatted;
            return;
          }
          if (price != null && price > 0) {
            _servicePriceController.text = price.toStringAsFixed(2);
          }
        });
      },
    );

    return ModernAdminPanel(
      title: 'admin.tasks_add'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.aiPrefill != null &&
                  (widget.aiPrefill!.hasLowConfidenceApartmentMatch ||
                      widget.aiPrefill!.warnings.isNotEmpty))
                _AiPrefillHintBanner(draft: widget.aiPrefill!),
              _AddTaskContextBar(
                apartmentsAsync: apartmentsAsync,
                selectedApartmentId: _selectedApartmentId,
                taskMode: _taskMode,
                initialReservationInfo: widget.initialReservationInfo,
              ),
              // Přepínač: Vázáno na apartmán vs Externí služba.
              Text(
                'tasks.form_task_type'.tr(),
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              SegmentedButton<_TaskFormMode>(
                segments: [
                  ButtonSegment<_TaskFormMode>(
                    value: _TaskFormMode.apartmentBound,
                    icon: const Icon(Icons.apartment, size: 18),
                    label: Text('tasks.form_mode_apartment'.tr()),
                  ),
                  ButtonSegment<_TaskFormMode>(
                    value: _TaskFormMode.externalService,
                    icon: const Icon(Icons.person_pin_circle, size: 18),
                    label: Text('tasks.form_mode_external'.tr()),
                  ),
                ],
                selected: {_taskMode},
                onSelectionChanged: (s) => setState(() => _taskMode = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.label_outline),
                  labelText: 'admin.task_field_title'.tr(),
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.translate_outlined),
                    tooltip: 'export_i18n.tooltip_edit'.tr(),
                    onPressed: () async {
                      final next = await ExportI18nEditorDialog.show(
                        context,
                        initial: _titleI18nDraft,
                      );
                      if (next != null && mounted) {
                        setState(() => _titleI18nDraft = next);
                      }
                    },
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return _taskMode == _TaskFormMode.apartmentBound
                        ? 'admin.validation_title_required'.tr()
                        : 'tasks.validation_service_name_required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.description_outlined),
                  labelText: 'admin.task_field_description'.tr(),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              // PROČ: Dispečer může připnout aktivní šablonu; body se zkopírují do úkolu po INSERTu.
              ref
                  .watch(checklistTemplatesListProvider)
                  .when(
                    data: (templates) {
                      final active = templates
                          .where((t) => t.isActive)
                          .toList();
                      final validIds = active.map((t) => t.id).toSet();
                      final validValue =
                          _selectedChecklistTemplateId != null &&
                              validIds.contains(_selectedChecklistTemplateId!)
                          ? _selectedChecklistTemplateId
                          : null;
                      if (validValue != _selectedChecklistTemplateId) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(
                              () => _selectedChecklistTemplateId = validValue,
                            );
                          }
                        });
                      }
                      return DropdownButtonFormField<String?>(
                        initialValue: validValue,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.checklist_rtl_outlined),
                          labelText: 'tasks.select_checklist_template'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('tasks.no_checklist'.tr()),
                          ),
                          ...active.map(
                            (t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(t.name),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedChecklistTemplateId = v),
                      );
                    },
                    loading: () => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'tasks.checklist_templates_load_error'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 12),
              catalogAsync.when(
                data: (catalog) {
                  // PROČ: U externí služby (AI i ručně) nesmí auto-výběr první položky
                  // (typicky úklid) přepsat transfer/letiště – dispečer vybere službu sám.
                  final allowEmptyService =
                      _taskMode == _TaskFormMode.externalService ||
                      widget.aiPrefill != null;
                  // PROČ: Výběr služby (ne jen typu) umožňuje předat requires_photo do metadata.
                  final items = _buildServiceDropdownItems(
                    catalog,
                    _selectedServiceId,
                    includeNone: allowEmptyService,
                  );
                  final validValue =
                      items.any((i) => i.value == _selectedServiceId)
                      ? _selectedServiceId
                      : (allowEmptyService
                          ? null
                          : (items.isNotEmpty ? items.first.value : null));
                  if (validValue != _selectedServiceId) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => setState(() => _selectedServiceId = validValue),
                    );
                  }
                  TenantServiceModel? service;
                  if (_selectedServiceId != null && catalog.isNotEmpty) {
                    try {
                      service = catalog.firstWhere(
                        (s) => s.id == _selectedServiceId,
                      );
                    } catch (e, st) {
                      AppLogger.error('admin_tasks_screen: služba v katalogu nenalezena (dialog úkolu)', e, st);
                    }
                  }
                  final taskType = service?.serviceType;
                  final showFlightField = _isTransferTaskType(taskType);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: validValue,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.list_alt_outlined),
                          labelText: 'admin.task_service_label'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: items,
                        onChanged: (v) =>
                            setState(() => _selectedServiceId = v),
                      ),
                      if (showFlightField) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _flightNumberController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.flight_takeoff_outlined,
                            ),
                            labelText: 'tasks.flight_number_label'.tr(),
                            hintText: 'tasks.flight_number_hint'.tr(),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => DropdownButtonFormField<String>(
                  initialValue: null,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.list_alt_outlined),
                    labelText: 'admin.task_service_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('common.loading'.tr()),
                    ),
                  ],
                  onChanged: null,
                ),
                error: (_, _) => DropdownButtonFormField<String>(
                  initialValue: null,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.list_alt_outlined),
                    labelText: 'admin.task_service_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('admin.task_type_label'.tr()),
                    ),
                  ],
                  onChanged: null,
                ),
              ),
              const SizedBox(height: 12),
              // Vázáno na apartmán: výběr bytu a cena služby. Externí: klient + název služby + adresa.
              if (_taskMode == _TaskFormMode.apartmentBound)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    apartmentsAsync.when(
                      data: (apartments) {
                        // Case-insensitive abecední řazení apartmánů pro lepší orientaci v roletce.
                        final sortedApartments = List<ApartmentRow>.from(apartments)
                          ..sort(
                            (a, b) => a.name
                                .toLowerCase()
                                .compareTo(b.name.toLowerCase()),
                          );
                        return DropdownButtonFormField<String?>(
                          initialValue: _selectedApartmentId,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.apartment),
                            labelText: 'admin.task_field_apartment'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'admin.validation_apartment_required_short'
                                    .tr(),
                              ),
                            ),
                            ...sortedApartments.map(
                              (a) => DropdownMenuItem<String?>(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedApartmentId = v),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'admin.validation_apartment_required_short'.tr()
                              : null,
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) =>
                          Text('admin.apartments_load_error'.tr()),
                    ),
                    const SizedBox(height: 12),
                    // Historical pricing: Cena služby – auto-fill z apartment_services, dispečer může přepsat.
                    TextFormField(
                      controller: _servicePriceController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.euro),
                        labelText: 'tasks.form_service_price'.tr(),
                        hintText: 'common.zero_placeholder'.tr(),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              if (_taskMode == _TaskFormMode.externalService) ...[
                TaskExternalClientPicker(
                  selectedClientId: _selectedClientId,
                  onChanged: (id) => setState(() => _selectedClientId = id),
                ),
                const SizedBox(height: 12),
                _TaskAddressQuickSelectWrapper(
                  selectedClientId: _selectedClientId,
                  controller: _customLocationController,
                  onFilled: () => setState(() {}),
                ),
                TextFormField(
                  controller: _customLocationController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    labelText: 'tasks.form_location'.tr(),
                    hintText: 'tasks.form_location_hint'.tr(),
                    border: OutlineInputBorder(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isGeocodingExternal
                        ? null
                        : () => _fetchGpsFromExternalLocation(),
                    icon: _isGeocodingExternal
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: Text('admin.geocoding_fetch_gps'.tr()),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _externalGpsController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.explore_outlined),
                    labelText: 'admin.geo_smart_gps_field'.tr(),
                    hintText: 'admin.geo_smart_gps_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                  maxLines: 2,
                  validator: (_) => GeoJsonPoint.validateOptionalSmartGpsText(
                        _externalGpsController.text,
                      )
                      ?.tr(),
                ),
                const SizedBox(height: 16),
                // Finanční blok pro externí službu.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'tasks.form_payment_block'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.euro),
                          labelText: 'tasks.form_price'.tr(),
                          hintText: 'common.zero_placeholder'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'tasks.form_payment_method'.tr(),
                        style: context.textTheme.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment<bool>(
                            value: true,
                            icon: const Icon(Icons.payments, size: 16),
                            label: Text('tasks.form_payment_cash'.tr()),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            icon: const Icon(Icons.receipt_long, size: 16),
                            label: Text('tasks.form_payment_invoice'.tr()),
                          ),
                        ],
                        selected: {_staffCollectsCash},
                        onSelectionChanged: (s) =>
                            setState(() => _staffCollectsCash = s.first),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _TaskAttachmentsSection(
                existingUrls: const [],
                onRemoveExisting: null,
                pendingFiles: _pendingAttachments,
                onRemovePending: (i) => setState(
                  () =>
                      _pendingAttachments = List.from(_pendingAttachments)
                        ..removeAt(i),
                ),
                onAddPressed: _pickAttachment,
                isUploading: _isSaving,
              ),
              const SizedBox(height: 12),
              // PROČ Začátek před výběrem personálu: Dostupný personál se filtruje podle data (availableTeamForTaskProvider).
              // Uživatel nejdřív zvolí plánovaný začátek a trvání, pak vidí roletku s lidmi – logický průchod formulářem.
              TextFormField(
                controller: _scheduledStartController,
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  labelText: 'admin.task_field_scheduled_start'.tr(),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final initial = _parseDateTime(
                    _scheduledStartController.text,
                  );
                  final result = await _showDateTimePicker(
                    context,
                    initial: initial,
                  );
                  if (result != null && mounted) {
                    setState(() => _scheduledStartController.text = result);
                  }
                },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'admin.validation_datetime_required_short'.tr()
                    : null,
              ),
              SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _durationMinutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.timelapse_outlined),
                  labelText: 'admin.task_field_duration_minutes'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) {
                    return 'admin.validation_duration_minutes_positive'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              teamAsync.when(
                data: (members) {
                  // BUGFIX: Majitelé apartmánů (owners) jsou klienti, nesmí se jim přiřazovat úkoly. Filtrujeme pouze reálný personál.
                  final staffMembers = members
                      .where((m) => m.role != 'property_owner')
                      .toList();
                  final seenValues = <String>{};
                  final unique = <TeamMember>[];
                  for (final m in staffMembers) {
                    final value = m.dropdownId;
                    if (value.isEmpty) continue;
                    if (seenValues.contains(value)) continue;
                    final byName = unique
                        .where((x) => x.name == m.name)
                        .toList();
                    if (byName.isNotEmpty) {
                      final existing = byName.first;
                      if (existing.profileId != null && m.profileId == null) {
                        continue;
                      }
                      if (existing.profileId == null && m.profileId != null) {
                        unique.removeWhere((x) => x.name == m.name);
                        seenValues.remove(existing.dropdownId);
                      }
                    }
                    seenValues.add(value);
                    unique.add(m);
                  }
                  // Case-insensitive abecední řazení personálu pro lepší orientaci v roletce.
                  unique.sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                  // PROČ stejná logika jako v Edit dialogu: sjednocení UX – v roletce „Přiřadit osobě“ zobrazujeme i pracovní pozice (role).
                  final pendingLabel = 'admin.team_status_pending'.tr();
                  final items = <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('admin.tasks_assign_nobody'.tr()),
                    ),
                    ...unique.map((m) {
                      final rolesString = m.roles.isNotEmpty
                          ? m.roles.map((r) => 'admin.role_$r'.tr()).join(', ')
                          : null;
                      final hasRoles =
                          rolesString != null && rolesString.isNotEmpty;
                      final String label;
                      if (hasRoles) {
                        label = m.isFromInvitation
                            ? '${m.name} ($pendingLabel) • $rolesString'
                            : '${m.name} ($rolesString)';
                      } else {
                        label = m.isFromInvitation
                            ? '${m.name} ($pendingLabel)'
                            : m.name;
                      }
                      return DropdownMenuItem<String?>(
                        value: m.dropdownId,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: m.isFromInvitation
                                ? context.colors.outline
                                : context.colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedAssignedTo,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline),
                          labelText: 'admin.task_field_assign_to'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        items: items,
                        onChanged: (v) => setState(() {
                          _selectedAssignedTo = v;
                          // PROČ: Hlavní pracovník nesmí být v „dalších“ – odebereme ho.
                          if (v != null && v.isNotEmpty) {
                            _selectedAdditionalUserIds =
                                _selectedAdditionalUserIds
                                    .where((id) => id != v)
                                    .toList();
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      _buildAdditionalAssigneesChips(
                        context: context,
                        members: unique,
                        mainAssigneeId: _selectedAssignedTo,
                        selectedIds: _selectedAdditionalUserIds,
                        onChanged: (v) =>
                            setState(() => _selectedAdditionalUserIds = v),
                      ),
                    ],
                  );
                },
                loading: () => DropdownButtonFormField<String?>(
                  initialValue: null,
                  items: const [],
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'admin.task_field_assign_to'.tr(),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    hintText: 'admin.team_loading_available'.tr(),
                  ),
                ),
                error: (e, st) => Text('admin.team_load_error'.tr()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _systemStatuses.contains(_status)
                    ? _status
                    : _systemStatuses.first,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.list_alt_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _systemStatuses
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(localizedTaskStatus(s)),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _status = v ?? _systemStatuses.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    if (_pendingAttachments.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('tasks.attachment_uploading'.tr()),
                    ],
                  ],
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}
