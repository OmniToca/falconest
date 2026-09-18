part of 'package:falconest/features/admin/admin_tasks_screen.dart';

/// Dialog s návrhy změn přiřazení – checkboxy pro výběr, potvrzení pouze vybraných.
/// Po kliku „Potvrdit vybrané“ volá applyRecalculationProposals a onApplied.
class RecalculateProposalsDialog extends StatefulWidget {
  const RecalculateProposalsDialog({
    super.key,
    required this.ref,
    required this.proposals,
    required this.onApplied,
  });

  final WidgetRef ref;
  final List<TaskRecalculationProposal> proposals;
  final VoidCallback onApplied;

  @override
  State<RecalculateProposalsDialog> createState() =>
      _RecalculateProposalsDialogState();
}

class _RecalculateProposalsDialogState
    extends State<RecalculateProposalsDialog> {
  /// Mapa taskId -> zda je řádek vybrán k potvrzení.
  late Map<String, bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {for (final p in widget.proposals) p.taskId: true};
  }

  bool get _allSelected => _selected.values.every((v) => v);
  void _toggleSelectAll() {
    setState(() {
      final val = !_allSelected;
      _selected = {for (final k in _selected.keys) k: val};
    });
  }

  /// Formátuje řádek návrhu; časy zobrazuje v lokálním čase (.toLocal()), aby dispečer neviděl falešný posun UTC vs Local.
  String _formatProposalRow(BuildContext context, TaskRecalculationProposal p) {
    final loc = context.locale.languageCode;
    final newly = 'admin.recalculate_proposals_newly'.tr();
    final newName = p.newAssigneeName ?? 'common.none'.tr();
    final newStartLocal = p.newStart.isUtc ? p.newStart.toLocal() : p.newStart;
    String newTime = '';
    try {
      newTime = DateFormat('HH:mm', loc).format(newStartLocal);
    } catch (e, st) {
      AppLogger.error('admin_tasks_screen: formát času návrhu přepočtu (nový začátek) selhal', e, st);
    }
    final hasOldAssignee =
        p.oldAssigneeName != null &&
        p.oldAssigneeName!.trim().isNotEmpty &&
        p.oldAssigneeName != 'common.none'.tr();
    if (hasOldAssignee) {
      final originally = 'admin.recalculate_proposals_originally'.tr();
      final oldStartLocal = p.oldStart.isUtc
          ? p.oldStart.toLocal()
          : p.oldStart;
      String oldTime = '';
      try {
        oldTime = DateFormat('HH:mm', loc).format(oldStartLocal);
      } catch (e, st) {
        AppLogger.error('admin_tasks_screen: formát času návrhu přepočtu (původní začátek) selhal', e, st);
      }
      return '${p.taskTitle}\n$originally: ${p.oldAssigneeName} ($oldTime)\n$newly: $newName ($newTime)';
    }
    return '${p.taskTitle}\n$newly: $newName ($newTime)';
  }

  Future<void> _confirmSelected() async {
    final approved = widget.proposals
        .where((p) => _selected[p.taskId] == true)
        .toList();
    if (approved.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await widget.ref
        .read(adminTasksProvider.notifier)
        .applyRecalculationProposals(approved);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onApplied();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('admin.recalculate_proposals_title'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: _allSelected,
                onChanged: (_) => _toggleSelectAll(),
                title: Text(
                  _allSelected
                      ? 'admin.recalculate_proposals_deselect_all'.tr()
                      : 'admin.recalculate_proposals_select_all'.tr(),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  itemCount: widget.proposals.length,
                  itemBuilder: (context, i) {
                    final p = widget.proposals[i];
                    return CheckboxListTile(
                      value: _selected[p.taskId] ?? false,
                      onChanged: (v) =>
                          setState(() => _selected[p.taskId] = v ?? false),
                      title: Text(
                        _formatProposalRow(context, p),
                        style: context.textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _confirmSelected,
          child: Text('admin.recalculate_proposals_confirm'.tr()),
        ),
      ],
    );
  }
}

// --- Add / Edit dialogy a pomocné funkce ---

/// Formátuje datum a čas pro zobrazení v UI. Vždy zobrazuje lokální čas.
/// PROČ toLocal(): Supabase vrací UTC (timestamptz). Bez převodu by se v CET zobrazoval posun -1h.
String _formatDateTime(DateTime d) {
  final local = d.isUtc ? d.toLocal() : d;
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

DateTime? _parseDateTime(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final trimmed = s.trim();
  try {
    if (trimmed.contains(' ')) {
      final parts = trimmed.split(' ');
      final dParts = parts[0].split('.');
      final tParts = parts[1].split(':');
      if (dParts.length >= 3 && tParts.length >= 2) {
        return DateTime(
          int.parse(dParts[2]),
          int.parse(dParts[1]),
          int.parse(dParts[0]),
          int.parse(tParts[0]),
          int.parse(tParts[1]),
        );
      }
    } else {
      final dParts = trimmed.split('.');
      if (dParts.length >= 3) {
        return DateTime(
          int.parse(dParts[2]),
          int.parse(dParts[1]),
          int.parse(dParts[0]),
          12,
          0,
        );
      }
    }
  } catch (e, st) {
    AppLogger.error('admin_tasks_screen: parsování data/času z řetězce (_parseDateTime) selhalo', e, st);
  }
  return null;
}

/// Odhad v minutách pro panel časové rentability v adminu.
///
/// PROČ: Stejná priorita jako u pracovníka ([parseTaskEstimateMinutes]); pokud v metadatech/regexu nic není,
/// použijeme stejný fallback jako pole trvání ve formuláři, aby čísla seděla s tím, co manažer vidí při editaci.
int _estimateMinutesForAdminProfitability(TaskRow t) {
  final parsed = parseTaskEstimateMinutes(t.description, t.metadata);
  if (parsed > 0) return parsed;
  return initialDurationMinutesForTask(t);
}

/// Skutečné trvání z `started_at` a `completed_at`. Null = úkol nedokončený nebo chybí začátek / rozpor časů.
int? _actualDurationMinutesForAdmin(TaskRow t) {
  final completed = t.completedAt;
  final started = t.startedAt;
  if (completed == null || started == null) return null;
  final diff = completed.difference(started).inMinutes;
  if (diff < 0) return null;
  return diff;
}

Future<String?> _showDateTimePicker(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  final initialDt = initial ?? now;
  final date = await showDatePicker(
    context: context,
    initialDate: initialDt,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initialDt.hour, minute: initialDt.minute),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (time == null || !context.mounted) return null;
  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  return _formatDateTime(dt);
}

/// Zda je typ úkolu transfer – pro zobrazení pole čísla letu a uložení do metadata.
bool _isTransferTaskType(String? taskType) {
  if (taskType == null || taskType.trim().isEmpty) return false;
  return [
    'transfer_in',
    'transfer_out',
    'transfer',
  ].contains(taskType.trim().toLowerCase());
}

/// Vrací položky dropdownu pro výběr služby z katalogu. Value = service.id.
/// [includeNone] – přidá položku "Žádná" pro Edit dialog, aby šlo odebrat službu.
/// [taskType] – u Edit dialogu: pokud úkol má task_type (např. check_out) ale service_id není v katalogu,
/// přidá se fallback položka s názvem z task_categories (Check-Out, Úklid), aby se neukazovala pomlčka.
List<DropdownMenuItem<String?>> _buildServiceDropdownItems(
  List<TenantServiceModel> catalog,
  String? selectedServiceId, {
  bool includeNone = false,
  String? taskType,
}) {
  if (catalog.isEmpty) {
    return [
      DropdownMenuItem(
        value: null,
        child: Text('admin.no_services_in_catalog'.tr()),
      ),
    ];
  }
  final items = catalog
      .map<DropdownMenuItem<String?>>(
        (s) => DropdownMenuItem(
          value: s.id,
          child: Text(s.name.trim().isEmpty ? s.serviceType : s.name),
        ),
      )
      .toList();
  if (includeNone) {
    items.insert(
      0,
      DropdownMenuItem(value: null, child: Text('common.none'.tr())),
    );
  }
  // Fallback: úkol má service_id (např. smazaná služba) a task_type – zobrazíme název typu místo pomlčky.
  final taskTypeNorm = taskType?.trim().toLowerCase().replaceAll('-', '_');
  if (taskTypeNorm != null &&
      taskTypeNorm.isNotEmpty &&
      selectedServiceId != null &&
      selectedServiceId.trim().isNotEmpty &&
      !catalog.any((s) => s.id == selectedServiceId)) {
    items.add(
      DropdownMenuItem<String?>(
        value: selectedServiceId,
        child: Text(taskTypeLabelKey(taskTypeNorm).tr()),
      ),
    );
  }
  return items;
}

