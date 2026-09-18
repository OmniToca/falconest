part of 'package:falconest/features/admin/admin_tasks_screen.dart';

/// Dialog pro úpravu existujícího úkolu.
class _EditTaskDialog extends ConsumerStatefulWidget {
  const _EditTaskDialog({
    required this.ref,
    required this.task,
    required this.onSaved,
    this.onReservationTap,
  });

  final WidgetRef ref;
  final TaskRow task;
  final VoidCallback onSaved;

  /// Callback při kliknutí na odkaz rezervace – zavře dialog a otevře detail rezervace.
  final void Function(String reservationId)? onReservationTap;

  @override
  ConsumerState<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends ConsumerState<_EditTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _scheduledStartController;
  late final TextEditingController _durationMinutesController;
  late final TextEditingController _customLocationController;
  late final TextEditingController _externalGpsController;
  late final TextEditingController _priceController;
  late final TextEditingController _flightNumberController;
  late String _selectedApartmentId;
  late String? _selectedClientId;
  late String? _selectedAssignedTo;

  /// Další přiřazení pracovníci (assigned_user_ids) – pro sdílení úkolu mezi více lidmi.
  late List<String> _selectedAdditionalUserIds;

  /// ID vybrané služby z katalogu. PROČ: Umožňuje aktualizovat metadata.requires_photo při změně služby.
  late String? _selectedServiceId;
  late String _status;
  late bool _staffCollectsCash;
  bool _isSaving = false;
  /// Probíhá geokódování textu lokace (externí úkol) přes Nominatim.
  bool _isGeocodingExternal = false;

  /// Vlastní barevné štítky (VIP, reklamace…) — persistují se v `metadata.custom_tags`.
  late List<TaskCustomTag> _customTags;

  /// UI override pro indikaci „vygenerováno/odesláno“ bez nutnosti zavírat a znovu otevírat dialog.
  ///
  /// PROČ: aktualizace DB last_communication_at je fire-and-forget, takže UI potřebuje okamžitou zpětnou vazbu.
  String? _lastCommunicationTemplateIdUi;
  DateTime? _lastCommunicationAtUi;

  /// Nově vybrané soubory k nahrání.
  List<PlatformFile> _pendingAttachments = [];

  /// Stávající URL z media_urls – uživatel může odstraňovat před uložením.
  late List<String> _existingMediaUrls;

  /// Uložení změn ve zmrazeném checklistu (`task_checklist_items`) při Uložit hlavního dialogu.
  final GlobalKey<TaskChecklistInstanceEditorSectionState>
  _taskChecklistEditorKey =
      GlobalKey<TaskChecklistInstanceEditorSectionState>();

  /// Ruční úprava `title_i18n`; `null` = nepřepisovat při UPDATE (ponechat DB), jinak nová mapa včetně `{}`.
  Map<String, dynamic>? _titleI18nDraft;

  /// Externí úkol = bez apartment_id (apartmentId prázdné).
  bool get _isExternal => widget.task.apartmentId.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _existingMediaUrls = List.from(widget.task.mediaUrls);
    final t = widget.task;
    // Externí úkol: custom_title je hlavní název; jinak title.
    final isExt = t.apartmentId.trim().isEmpty;
    _titleController = TextEditingController(
      text: isExt ? (t.customTitle ?? t.title) : t.title,
    );
    _descriptionController = TextEditingController(text: t.description);
    // PROČ: Začátek z scheduled_start; fallback due_date kvůli starým řádkům bez rozlišení intervalu.
    final startForUi = t.scheduledStart ?? t.dueDate;
    _scheduledStartController = TextEditingController(
      text: _formatDateTime(startForUi),
    );
    _durationMinutesController = TextEditingController(
      text: initialDurationMinutesForTask(t).toString(),
    );
    _customLocationController = TextEditingController(
      text: t.customLocation ?? '',
    );
    final extGpsInitial = (t.latitude != null && t.longitude != null)
        ? '${t.latitude}, ${t.longitude}'
        : '';
    _externalGpsController = TextEditingController(text: extGpsInitial);
    _selectedApartmentId = t.apartmentId;
    _selectedClientId = t.clientId;
    _selectedAssignedTo = t.assignedTo;
    _selectedAdditionalUserIds = List.from(t.assignedUserIds);
    _selectedServiceId = t.serviceId;
    _status = normalizeToSystemStatus(t.status);
    _lastCommunicationTemplateIdUi = t.lastCommunicationTemplateId;
    _lastCommunicationAtUi = t.lastCommunicationAt;
    // amount_to_collect = hotovost u personálu; service_price = částka k fakturaci (sdílené UI pole).
    final amt = t.metadata?['amount_to_collect'];
    final svcPrice = t.metadata?['service_price'];
    final payerType = (t.metadata?['payer_type'] as String?)?.trim().toLowerCase();
    _staffCollectsCash =
        payerType == 'guest' || (amt != null && amt is num && amt > 0);
    double? priceForField;
    if (_staffCollectsCash && amt is num && amt > 0) {
      priceForField = amt.toDouble();
    } else if (svcPrice is num && svcPrice > 0) {
      priceForField = svcPrice.toDouble();
    } else if (svcPrice != null) {
      priceForField = double.tryParse(svcPrice.toString());
    }
    _priceController = TextEditingController(
      text: priceForField != null && priceForField > 0
          ? priceForField.toString()
          : '',
    );
    // PROČ: Číslo letu z metadat – řidič získá proklik na FlightRadar24.
    final fn = t.metadata?['flight_number'];
    _flightNumberController = TextEditingController(
      text: fn is String ? fn.trim() : (fn?.toString().trim() ?? ''),
    );
    _customTags = TaskCustomTag.listFromMetadata(t.metadata);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _scheduledStartController.dispose();
    _durationMinutesController.dispose();
    _customLocationController.dispose();
    _externalGpsController.dispose();
    _priceController.dispose();
    _flightNumberController.dispose();
    super.dispose();
  }

  /// Doplní GPS z pole lokace u externího úkolu (úprava).
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
    if (_isExternal &&
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
    if (_isExternal && _titleController.text.trim().isEmpty) {
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

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final apartments = ref.read(apartmentsFullListProvider).valueOrNull ?? [];
    final apartmentIdToSave = _isExternal
        ? null
        : (apartments.any((a) => a.id == _selectedApartmentId)
              ? _selectedApartmentId
              : (apartments.isNotEmpty
                    ? apartments.first.id
                    : _selectedApartmentId));

    try {
      // PROČ: Nejdřív instance checklistu (`task_checklist_items`); šablony katalogu zůstávají nedotčené.
      await _taskChecklistEditorKey.currentState?.persistChecklistIfNeeded(
        tenantId,
      );
      if (!context.mounted) {
        setState(() => _isSaving = false);
        return;
      }
      final catalog = ref.read(tenantServicesProvider).valueOrNull ?? [];
      TenantServiceModel? service;
      if (_selectedServiceId != null && catalog.isNotEmpty) {
        try {
          service = catalog.firstWhere((s) => s.id == _selectedServiceId);
        } catch (e, st) {
          AppLogger.error('admin_tasks_screen: služba v katalogu nenalezena (úprava úkolu)', e, st);
        }
      }
      final taskType = service?.serviceType ?? widget.task.taskType;
      final mergedMetadata = Map<String, dynamic>.from(
        widget.task.metadata ?? {},
      );
      TaskCustomTag.applyToMetadata(mergedMetadata, _customTags);
      mergedMetadata['requires_photo'] = service?.requiresPhoto == true;
      if (mergedMetadata['requires_photo'] == false) {
        mergedMetadata.remove('requires_photo');
      }

      // PROČ: Externí úkol – service_price pro fakturaci; amount_to_collect jen při výběru hotovosti.
      if (_isExternal) {
        final price = double.tryParse(_priceController.text.trim());
        // Zápis manuálně zadané ceny pro externí službu do metadat kvůli fakturaci.
        if (price != null && price > 0) {
          mergedMetadata['service_price'] = price;
          if (_staffCollectsCash) {
            mergedMetadata['amount_to_collect'] = price;
          } else {
            mergedMetadata.remove('amount_to_collect');
          }
        } else {
          mergedMetadata.remove('service_price');
          mergedMetadata.remove('amount_to_collect');
        }
      }

      // PROČ: Číslo letu pro transfery – přidáme/odebereme dle zadané hodnoty, bez mazání ostatních metadat.
      if (_isTransferTaskType(taskType)) {
        final fn = _flightNumberController.text.trim();
        if (fn.isNotEmpty) {
          mergedMetadata['flight_number'] = fn;
        } else {
          mergedMetadata.remove('flight_number');
        }
      }

      // KROK 3 OPRAVA: Explicitní payer_type při úpravě úkolu.
      mergedMetadata['payer_type'] = _isExternal
          ? (_staffCollectsCash ? 'guest' : 'client')
          : 'owner';

      // PROČ: Sjednocení s interval scheduled_start–due_date; reporty a mobilní UI čtou estimated_minutes.
      mergedMetadata['estimated_minutes'] = durationMinutes;

      final previousStatus = normalizeToSystemStatus(widget.task.status);
      final isTransitionToCompleted =
          _status == 'completed' && previousStatus != 'completed';

      // PROČ: Cash dialog musí vyskočit při skutečném přechodu na completed (ne při každém dalším editu),
      // aby dispečer při uzavření úkolu vždy potvrdil výběr hotovosti do peněženky.
      if (isTransitionToCompleted) {
        if (!context.mounted) {
          setState(() => _isSaving = false);
          return;
        }
        // PROČ: Dialog pro zápis hotovosti musí reagovat na celý plánovaný výběr od hosta:
        // část pro agenturu (`amount_to_collect`) + průtok pro majitele (`transit_amount_to_collect`).
        // Dříve jsme sledovali jen amount_to_collect, takže rent_collection / transit-only úkoly
        // dialog přeskočily a hotovost se nezapsala.
        final sourceMetadata = Map<String, dynamic>.from(widget.task.metadata ?? {});
        final amountAgencyRaw =
            mergedMetadata['amount_to_collect'] ?? sourceMetadata['amount_to_collect'];
        final amountAgency = (amountAgencyRaw is num)
            ? amountAgencyRaw.toDouble()
            : double.tryParse(amountAgencyRaw?.toString() ?? '') ?? 0.0;
        final amountTransitRaw =
            mergedMetadata['transit_amount_to_collect'] ??
            sourceMetadata['transit_amount_to_collect'];
        final amountTransit = (amountTransitRaw is num)
            ? amountTransitRaw.toDouble()
            : double.tryParse(amountTransitRaw?.toString() ?? '') ?? 0.0;
        final amount = amountAgency + amountTransit;
        if (amount > 0) {
          final recordToWallet = await showCashCollectionOnCompleteDialog(
            // ignore: use_build_context_synchronously
            context,
          );
          // PROČ: Kontrola musí odpovídat BuildContextu dialogu, ne jen State.mounted.
          if (!context.mounted) {
            setState(() => _isSaving = false);
            return;
          }
          if (recordToWallet) {
            final profileId = ref.read(authNotifierProvider).state.profileId;
            if (profileId != null && profileId.isNotEmpty) {
              try {
                await CashWalletRepository.instance.recordCashCollection(
                  taskId: widget.task.id,
                  amount: amount,
                  tenantId: tenantId,
                  profileId: profileId,
                  expectedAmount: amount,
                  reservationId: widget.task.reservationId,
                );
                if (mounted) ref.invalidate(employeeCashWalletsProvider);
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'common.generic_error_user_friendly'.tr(),
                      ),
                      backgroundColor: context.colors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
            }
          }
        }
      }

      final assignedToUuid =
          _selectedAssignedTo != null && _selectedAssignedTo!.isNotEmpty
          ? _selectedAssignedTo
          : null;
      final scheduledIso = scheduledStart.toUtc().toIso8601String();
      final dueIso = dueDate.toUtc().toIso8601String();
      final titleText = _titleController.text.trim();

      // KROK 1: Nahrání nových příloh na Supabase Storage.
      List<String> mediaUrls = List.from(_existingMediaUrls);
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

      // Při přepnutí na byt explicitně vynulujeme client_id, aby v DB nezůstal starý odkaz (přeřazení).
      final updateFields = <String, dynamic>{
        'apartment_id': apartmentIdToSave,
        if (_isExternal && _selectedClientId != null)
          'client_id': _selectedClientId,
        if (!_isExternal) 'client_id': null,
        if (_isExternal) 'custom_title': titleText,
        if (_isExternal)
          'custom_location': _customLocationController.text.trim(),
        'assigned_to': assignedToUuid,
        'assigned_user_ids': _selectedAdditionalUserIds,
        'title': titleText,
        'description': _descriptionController.text.trim(),
        'status': _status,
        'task_type': taskType,
        'due_date': dueIso,
        'scheduled_start': scheduledIso,
        'metadata': mergedMetadata,
        'service_id': service?.id,
        'media_urls': mediaUrls,
        if (_titleI18nDraft != null) 'title_i18n': _titleI18nDraft,
      };
      if (_isExternal) {
        final g = GeoJsonPoint.tryParseSmartGpsText(_externalGpsController.text);
        updateFields['geo_location'] = GeoJsonPoint.toPostgrestJson(
          g?.latitude,
          g?.longitude,
        );
      }
      // Při novém přiřazení vymažeme Soft-Unassign kontext (UI už neukáže „Původní pracovník“).
      if (assignedToUuid != null && assignedToUuid.isNotEmpty) {
        updateFields['unassigned_info'] = null;
      }
      await ref
          .read(adminTasksProvider.notifier)
          .updateTaskInAdmin(widget.task.id, updateFields);
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
      if (kDebugMode) debugPrint('task update Postgrest: ${e.message}');
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

  /// Sekce „Komunikace s hostem“ – seznam šablon odpovídajících taskType + general, indikátor odeslání z tasks.
  Widget _buildTaskCommunicationSection(BuildContext context) {
    final taskType = (widget.task.taskType).trim().toLowerCase();
    final templatesAsync = ref.watch(messageTemplatesAdminProvider);
    final reservations =
        ref.watch(adminReservationsProvider).valueOrNull ?? <ReservationRow>[];
    final clients =
        ref.watch(clientsFullListProvider).valueOrNull ?? <ClientModel>[];
    final reservation = widget.task.reservationId != null
        ? reservations
              .where((r) => r.id == widget.task.reservationId)
              .firstOrNull
        : null;
    final client = widget.task.clientId != null
        ? clients.where((c) => c.id == widget.task.clientId).firstOrNull
        : null;
    if (reservation == null && client == null) return const SizedBox.shrink();
    final guestLangLower = reservation?.guestLanguage?.trim().isNotEmpty == true
        ? reservation!.guestLanguage!.trim().toLowerCase()
        : (client?.languageCode?.trim().isNotEmpty == true
              ? client!.languageCode!.trim().toLowerCase()
              : 'en');
    final apartments =
        ref.watch(apartmentsFullListProvider).valueOrNull ?? <ApartmentRow>[];
    final apt = widget.task.apartmentId.isNotEmpty
        ? apartments.where((a) => a.id == widget.task.apartmentId).firstOrNull
        : null;
    final aptCtx = apt != null
        ? ApartmentPlaceholderContext(
            name: apt.name,
            address: apt.address,
            keybox: apt.keybox,
            parkingInstructions: apt.parkingInstructions,
            reviewLink: apt.reviewLink,
            ownerNotes: apt.ownerNotes,
          )
        : null;
    final ctx = MessageTemplateSelectorContext.fromAdminTask(
      widget.task,
      reservation: reservation,
      apartment: aptCtx,
      client: client,
      tenantIanaTimezone: ref.read(authNotifierProvider).state.effectiveTenantTimezone,
    );

    final lastTemplateId =
        _lastCommunicationTemplateIdUi ??
        widget.task.lastCommunicationTemplateId;
    final lastAt = _lastCommunicationAtUi ?? widget.task.lastCommunicationAt;

    return templatesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (allTemplates) {
        final filtered = allTemplates.where((t) {
          if (t.channel != 'whatsapp') return false;
          final body = t.resolvedBodyForGuest(guestLangLower);
          if (body.trim().isEmpty) return false;

          final trig = t.triggerContext?.trim().toLowerCase();
          if (trig == null || trig.isEmpty) return true;
          return trig == taskType;
        }).toList();
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'admin.reservations_communication_section'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Text(
                  'communication.no_templates_for_task_language'.tr(
                    namedArgs: {'language': guestLangLower.toUpperCase()},
                  ),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...filtered.map((template) {
                  final isSent = lastTemplateId == template.id;
                  final dateStr = (isSent && lastAt != null)
                      ? DateFormat(
                          'd.M.',
                          context.locale.languageCode,
                        ).format(lastAt.toLocal())
                      : null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      template.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSent && lastAt != null) ...[
                          Icon(
                            Icons.check_circle,
                            color: context.customColors.success,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'communication.message_generated_label'.tr(
                              namedArgs: {'date': dateStr ?? ''},
                            ),
                            style: context.textTheme.labelLarge?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          icon: Icon(
                            Icons.chat,
                            color: context.customColors.success,
                            size: 22,
                          ),
                          tooltip:
                              'communication.template_selector_whatsapp_tooltip'
                                  .tr(),
                          onPressed: () async {
                            final ok = await WhatsAppSenderService.send(
                              context,
                              ref,
                              ctx,
                              WhatsAppTemplateData(
                                name: template.name,
                                body: template.resolvedBodyForGuest(
                                  guestLangLower,
                                ),
                                triggerContext: template.triggerContext,
                                templateId: template.id,
                              ),
                            );
                            if (!mounted) return;
                            if (ok) {
                              setState(() {
                                _lastCommunicationTemplateIdUi = template.id;
                                _lastCommunicationAtUi = DateTime.now().toUtc();
                              });
                              ref.invalidate(adminTasksProvider);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    // Dostupný personál v den úkolu (smlouva + schválené absence) – stejná logika jako automatický generátor.
    final taskDate =
        _parseDateTime(_scheduledStartController.text.trim()) ??
        widget.task.scheduledStart ??
        widget.task.dueDate;
    final teamAsync = ref.watch(availableTeamForTaskProvider(taskDate));
    final catalogAsync = ref.watch(tenantServicesProvider);
    final lockedTaskIds =
        ref.watch(lockedFinancialTaskIdsProvider).valueOrNull ?? {};

    // Finanční zámek: úkol s výplatami nebo provizemi nelze měnit (ochrana účetnictví).
    final isFinanciallyLocked = lockedTaskIds.contains(widget.task.id);
    // Auditing: Zámek editace pro dokončené úkoly – neměnnost historie pro účetní audit.
    final isReadOnly =
        isFinanciallyLocked ||
        normalizeToSystemStatus(widget.task.status) == 'completed';
    // Přeřazení: u dokončených úkolů ponecháme editovatelné vazby (klient / byt), aby šlo opravit sirotky.
    final isReassignEnabled = !isFinanciallyLocked;

    final refNum = widget.task.referenceNumber?.trim();
    final editTitle = refNum != null && refNum.isNotEmpty
        ? '${'admin.tasks_edit'.tr()} • #$refNum'
        : 'admin.tasks_edit'.tr();
    return ModernAdminPanel(
      title: editTitle,
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminTaskCrossLinkRow(task: widget.task),
              _TaskContextSection(
                task: widget.task,
                onReservationTap: widget.onReservationTap,
              ),
              const SizedBox(height: AppSpacing.md),
              _TaskTimeProfitabilitySection(task: widget.task),
              if (isFinanciallyLocked) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.customColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.customColors.warning.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock,
                        color: context.customColors.warning,
                        size: 24,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'admin.task_financially_locked'.tr(),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.customColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (isReadOnly && !isFinanciallyLocked) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: context.colors.primary, size: 24),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'tasks.task_locked_info'.tr(),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (!isFinanciallyLocked) ...[
                const SizedBox(height: 16),
              ],
              // Sekce Přeřazení – oprava vazby na klienta/byt (sirotčí úkoly po smazání klienta v CRM).
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.tasks_reassign_section'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'admin.tasks_reassign_section_hint'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextFormField(
                controller: _titleController,
                readOnly: isReadOnly,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.label_outline),
                  labelText: 'admin.task_field_title'.tr(),
                  border: OutlineInputBorder(),
                  suffixIcon: isReadOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.translate_outlined),
                          tooltip: 'export_i18n.tooltip_edit'.tr(),
                          onPressed: () async {
                            final next = await ExportI18nEditorDialog.show(
                              context,
                              initial: _titleI18nDraft ?? widget.task.titleI18n,
                            );
                            if (next != null && mounted) {
                              setState(() => _titleI18nDraft = next);
                            }
                          },
                        ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return _isExternal
                        ? 'tasks.validation_service_name_required'.tr()
                        : 'admin.validation_title_required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                readOnly: isReadOnly,
                maxLines: 3,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.description_outlined),
                  labelText: 'admin.task_field_description'.tr(),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              TaskCustomTagsEditor(
                initialTags: _customTags,
                readOnly: isReadOnly,
                onChanged: (tags) => setState(() => _customTags = tags),
              ),
              TaskMetadataSection(metadata: widget.task.metadata),
              if (widget.task.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TaskMediaSection(mediaUrls: widget.task.mediaUrls),
              ],
              const SizedBox(height: 12),
              catalogAsync.when(
                data: (catalog) {
                  // PROČ: Výběr služby umožňuje aktualizovat metadata.requires_photo při změně služby.
                  // taskType: fallback položka, když service_id není v katalogu (např. Check-Out z task_categories).
                  final items = _buildServiceDropdownItems(
                    catalog,
                    _selectedServiceId,
                    includeNone: true,
                    taskType: widget.task.taskType,
                  );
                  final validValue =
                      items.any((i) => i.value == _selectedServiceId)
                      ? _selectedServiceId
                      : (items.isNotEmpty
                            ? items.first.value
                            : _selectedServiceId);
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
                      AppLogger.error('admin_tasks_screen: služba v katalogu nenalezena (read-only dialog úkolu)', e, st);
                    }
                  }
                  final taskType = service?.serviceType ?? widget.task.taskType;
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
                        onChanged: isReadOnly
                            ? null
                            : (v) => setState(() => _selectedServiceId = v),
                      ),
                      if (showFlightField) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _flightNumberController,
                          readOnly: isReadOnly,
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
                loading: () => DropdownButtonFormField<String?>(
                  initialValue: _selectedServiceId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.list_alt_outlined),
                    labelText: 'admin.task_service_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _selectedServiceId,
                      child: Text('common.loading'.tr()),
                    ),
                  ],
                  onChanged: null,
                ),
                error: (_, _) => DropdownButtonFormField<String?>(
                  initialValue: _selectedServiceId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.list_alt_outlined),
                    labelText: 'admin.task_service_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _selectedServiceId,
                      child: Text('admin.task_type_label'.tr()),
                    ),
                  ],
                  onChanged: null,
                ),
              ),
              const SizedBox(height: 12),
              // Vázáno na apartmán: výběr bytu. Externí: klient + název služby + adresa + platba.
              // Přeřazení: dropdowny zůstávají editovatelné i u dokončeného úkolu (isReassignEnabled).
              if (!_isExternal)
                apartmentsAsync.when(
                  data: (apartments) {
                    // Case-insensitive abecední řazení apartmánů pro lepší orientaci v roletce.
                    final sortedApartments = List<ApartmentRow>.from(apartments)
                      ..sort(
                        (a, b) => a.name
                            .toLowerCase()
                            .compareTo(b.name.toLowerCase()),
                      );
                    final validId =
                        sortedApartments.any((a) => a.id == _selectedApartmentId)
                        ? _selectedApartmentId
                        : (sortedApartments.isNotEmpty
                              ? sortedApartments.first.id
                              : null);
                    return DropdownButtonFormField<String?>(
                      initialValue: validId,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.apartment),
                        labelText: 'admin.task_field_apartment'.tr(),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'admin.validation_apartment_required_short'.tr(),
                          ),
                        ),
                        ...sortedApartments.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: isReassignEnabled
                          ? (v) =>
                                setState(() => _selectedApartmentId = v ?? '')
                          : null,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'admin.validation_apartment_required_short'.tr()
                          : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, st) => Text('admin.apartments_load_error'.tr()),
                ),
              if (_isExternal) ...[
                TaskExternalClientPicker(
                  selectedClientId: _selectedClientId,
                  onChanged: (id) => setState(() => _selectedClientId = id),
                  enabled: isReassignEnabled,
                  allowOrphanLabel: true,
                ),
                const SizedBox(height: 12),
                _TaskAddressQuickSelectWrapper(
                  selectedClientId: _selectedClientId,
                  controller: _customLocationController,
                  onFilled: () => setState(() {}),
                  enabled: !isReadOnly,
                ),
                TextFormField(
                  controller: _customLocationController,
                  readOnly: isReadOnly,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    labelText: 'tasks.form_location'.tr(),
                    hintText: 'tasks.form_location_hint'.tr(),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (!isReadOnly)
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
                  readOnly: isReadOnly,
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
                        readOnly: isReadOnly,
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
                        onSelectionChanged: isReadOnly
                            ? null
                            : (s) =>
                                  setState(() => _staffCollectsCash = s.first),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _TaskAttachmentsSection(
                existingUrls: _existingMediaUrls,
                onRemoveExisting: isReadOnly
                    ? null
                    : (i) => setState(
                        () =>
                            _existingMediaUrls = List.from(_existingMediaUrls)
                              ..removeAt(i),
                      ),
                pendingFiles: _pendingAttachments,
                onRemovePending: isReadOnly
                    ? (_) {}
                    : (i) => setState(
                        () =>
                            _pendingAttachments = List.from(_pendingAttachments)
                              ..removeAt(i),
                      ),
                onAddPressed: isReadOnly ? null : _pickAttachment,
                isUploading: _isSaving,
              ),
              const SizedBox(height: 12),
              TaskChecklistInstanceEditorSection(
                key: _taskChecklistEditorKey,
                taskId: widget.task.id,
                readOnly: isReadOnly,
              ),
              const SizedBox(height: 12),
              teamAsync.when(
                data: (members) {
                  // BUGFIX: Majitelé apartmánů (owners) jsou klienti, nesmí se jim přiřazovat úkoly. Filtrujeme pouze reálný personál.
                  final staffMembers = members
                      .where((m) => m.role != 'property_owner')
                      .toList();
                  final availableIds = staffMembers
                      .map((m) => m.dropdownId)
                      .toSet();
                  // Původně přiřazený není v tento termín dostupný → datově musí být null, UX varování zobrazíme pod dropdownem.
                  final isOriginalUnavailable =
                      widget.task.assignedTo != null &&
                      widget.task.assignedTo!.isNotEmpty &&
                      !availableIds.contains(widget.task.assignedTo!);
                  if (isOriginalUnavailable &&
                      _selectedAssignedTo == widget.task.assignedTo) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedAssignedTo = null);
                    });
                  }
                  final pendingLabel = 'admin.team_status_pending'.tr();
                  final dropdownItems = <DropdownMenuItem<String?>>[];
                  final seenIds = <String>{};

                  void addProfileItem(
                    String id,
                    String name,
                    bool isPending, {
                    List<String> roles = const [],
                  }) {
                    if (id.isEmpty || seenIds.contains(id)) return;
                    seenIds.add(id);
                    final rolesString = roles.isNotEmpty
                        ? roles.map((r) => 'admin.role_$r'.tr()).join(', ')
                        : null;
                    final hasRoles =
                        rolesString != null && rolesString.isNotEmpty;
                    final String label;
                    if (hasRoles) {
                      label = isPending
                          ? '$name ($pendingLabel) • $rolesString'
                          : '$name ($rolesString)';
                    } else {
                      label = isPending ? '$name ($pendingLabel)' : name;
                    }
                    dropdownItems.add(
                      DropdownMenuItem<String?>(
                        value: id,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isPending
                                ? context.colors.outline
                                : context.colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }

                  dropdownItems.add(
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('admin.tasks_assign_nobody'.tr()),
                    ),
                  );
                  // Case-insensitive abecední řazení personálu pro lepší orientaci v roletce.
                  final sortedStaffMembers = List<TeamMember>.from(staffMembers)
                    ..sort(
                      (a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                    );
                  for (final m in sortedStaffMembers) {
                    addProfileItem(
                      m.dropdownId,
                      m.name,
                      m.isFromInvitation,
                      roles: m.roles,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue:
                            _selectedAssignedTo != null &&
                                seenIds.contains(_selectedAssignedTo)
                            ? _selectedAssignedTo
                            : null,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline),
                          labelText: 'admin.task_field_assign_to'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        items: dropdownItems,
                        onChanged: isReadOnly
                            ? null
                            : (v) => setState(() {
                                _selectedAssignedTo = v;
                                if (v != null && v.isNotEmpty) {
                                  _selectedAdditionalUserIds =
                                      _selectedAdditionalUserIds
                                          .where((id) => id != v)
                                          .toList();
                                }
                              }),
                      ),
                      if (isOriginalUnavailable) ...[
                        SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: context.colors.error,
                              size: 20,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'admin.task_assignee_original_unavailable_warning'
                                    .tr(
                                      namedArgs: {
                                        'name':
                                            widget.task.assignedToName ??
                                            'planning_calendar.unknown'.tr(),
                                      },
                                    ),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (widget.task.assignedTo == null &&
                          widget.task.unassignedInfo != null &&
                          widget.task.unassignedInfo!.isNotEmpty) ...[
                        SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: context.colors.error,
                              size: 20,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'admin.task_auto_unassigned_warning'.tr(
                                  namedArgs: {
                                    'name':
                                        (widget.task.unassignedInfo!['previous_name']
                                                    ?.toString()
                                                    .trim() ??
                                                '')
                                            .isEmpty
                                        ? 'planning_calendar.unknown'.tr()
                                        : widget
                                              .task
                                              .unassignedInfo!['previous_name']
                                              .toString(),
                                  },
                                ),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildAdditionalAssigneesChips(
                        context: context,
                        members: staffMembers,
                        mainAssigneeId: _selectedAssignedTo,
                        selectedIds: _selectedAdditionalUserIds,
                        onChanged: (v) =>
                            setState(() => _selectedAdditionalUserIds = v),
                        isReadOnly: isReadOnly,
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('admin.team_load_error'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _scheduledStartController,
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  labelText: 'admin.task_field_scheduled_start'.tr(),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: isReadOnly
                    ? null
                    : () async {
                        final initial = _parseDateTime(
                          _scheduledStartController.text,
                        );
                        final result = await _showDateTimePicker(
                          context,
                          initial: initial,
                        );
                        if (result != null && mounted) {
                          setState(
                            () => _scheduledStartController.text = result,
                          );
                        }
                      },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'admin.validation_datetime_required_short'.tr()
                    : null,
              ),
              SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _durationMinutesController,
                readOnly: isReadOnly,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.timelapse_outlined),
                  labelText: 'admin.task_field_duration_minutes'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (isReadOnly) return null;
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) {
                    return 'admin.validation_duration_minutes_positive'.tr();
                  }
                  return null;
                },
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
                onChanged: isReadOnly
                    ? null
                    : (v) =>
                          setState(() => _status = v ?? _systemStatuses.first),
              ),
              const SizedBox(height: 24),
              _buildTaskCommunicationSection(context),
              const SizedBox(height: 24),
              TaskAuditHistorySection(taskId: widget.task.id),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(isReadOnly ? 'common.close'.tr() : 'common.cancel'.tr()),
        ),
        // U dokončeného úkolu zobrazíme Uložit i při isReadOnly, pokud je povoleno přeřazení (oprava vazby na klienta/byt).
        if (!isReadOnly || isReassignEnabled) ...[
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
      ],
    );
  }
}
