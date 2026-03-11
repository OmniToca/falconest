import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';

/// Zobrazí potvrzovací dialog pro výběr hotovosti při dokončení úkolu.
///
/// Pokud [detail.metadata] obsahuje amount_to_collect > 0, zobrazí dialog.
/// Parametr [forceShowForExtraOnly] umožňuje zobrazit dialog i s plánovanou částkou 0
/// (např. pro úklid – uklízečka může zadat jen extra hotovost).
///
/// Návratová hodnota:
/// - null = dialog nebyl zobrazen (žádná částka a ne forceShow), volající provede běžné dokončení,
/// - true = úkol byl dokončen (ANO nebo NEVYBRAL), volající může zavřít obrazovku,
/// - false = uživatel zrušil, úkol zůstává nedokončený.
///
/// Při potvrzení převzetí se zapíše skutečně převzatá částka; při nedoplatku je povinný důvod.
Future<bool?> maybeShowCashCollectionDialog(
  BuildContext context,
  WidgetRef ref,
  dynamic detail, {
  required String taskId,
  required VoidCallback onCompleted,
  bool forceShowForExtraOnly = false,
  bool completeTaskOnConfirm = true,
  List<String>? mediaUrls,
  List<String>? localPhotoPaths,
}) async {
  final meta = detail?.metadata;
  if (meta == null || meta is! Map) {
    if (!forceShowForExtraOnly) return null;
  }

  final amountRaw = meta?['amount_to_collect'];
  final plannedAmount = (amountRaw is num)
      ? amountRaw.toDouble()
      : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null) ?? 0;

  if (plannedAmount <= 0 && !forceShowForExtraOnly) return null;

  final formatted = formatTaskAmount(context, ref, plannedAmount);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CashCollectionDialogContent(
      plannedAmount: plannedAmount,
      formattedPlanned: formatted,
      forceShowForExtraOnly: forceShowForExtraOnly,
      taskId: taskId,
      ref: ref,
      onCompleted: onCompleted,
      completeTaskOnConfirm: completeTaskOnConfirm,
      mediaUrls: mediaUrls,
      localPhotoPaths: localPhotoPaths,
    ),
  );
}

/// Důvody nedoplatku – klíče pro i18n (worker.cash_collection_reason_*).
const _shortfallReasonKeys = ['guest_will_transfer', 'owner_invoice', 'other'];

/// Vnitřní StatefulWidget pro dialog se skutečně převzatou částkou a důvodem nedoplatku.
class _CashCollectionDialogContent extends StatefulWidget {
  const _CashCollectionDialogContent({
    required this.plannedAmount,
    required this.formattedPlanned,
    required this.forceShowForExtraOnly,
    required this.taskId,
    required this.ref,
    required this.onCompleted,
    this.completeTaskOnConfirm = true,
    this.mediaUrls,
    this.localPhotoPaths,
  });

  final double plannedAmount;
  final String formattedPlanned;
  final bool forceShowForExtraOnly;
  final String taskId;
  final WidgetRef ref;
  final VoidCallback onCompleted;
  final bool completeTaskOnConfirm;
  final List<String>? mediaUrls;
  final List<String>? localPhotoPaths;

  @override
  State<_CashCollectionDialogContent> createState() => _CashCollectionDialogContentState();
}

class _CashCollectionDialogContentState extends State<_CashCollectionDialogContent> {
  late final TextEditingController _actualAmountController;
  final _shortfallNoteController = TextEditingController();
  String? _selectedShortfallReason;

  void _onActualAmountChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _actualAmountController = TextEditingController(
      text: widget.plannedAmount > 0 ? widget.plannedAmount.toStringAsFixed(2) : '',
    );
    _actualAmountController.addListener(_onActualAmountChanged);
  }

  @override
  void dispose() {
    _actualAmountController.removeListener(_onActualAmountChanged);
    _actualAmountController.dispose();
    _shortfallNoteController.dispose();
    super.dispose();
  }

  double? _parseActualAmount() {
    final t = _actualAmountController.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Rozdíl: skutečně převzatá − očekávaná. Kladný = dýško, záporný = nedoplatek.
  double? get _diff {
    final actual = _parseActualAmount();
    if (actual == null) return null;
    return actual - widget.plannedAmount;
  }

  /// Zobrazí text rozdílu: částka sedí / dýško / chybí X.
  Widget _buildDiffText(BuildContext context, double diff) {
    if (diff == 0) {
      return Text(
        'worker.cash_collection_diff_exact'.tr(),
        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      );
    }
    if (diff > 0) {
      final formatted = formatTaskAmount(context, widget.ref, diff);
      return Text(
        'worker.cash_collection_diff_tip'.tr(namedArgs: {'amount': formatted}),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.green.shade700),
      );
    }
    final formatted = formatTaskAmount(context, widget.ref, diff.abs());
    return Text(
      'worker.cash_collection_diff_missing'.tr(namedArgs: {'amount': formatted}),
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade700),
    );
  }

  Future<void> _onYes() async {
    final actual = _parseActualAmount();
    if (actual == null || actual <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.cash_collection_validation_positive'.tr())),
        );
      }
      return;
    }

    final d = _diff ?? 0;
    if (d < 0 && (_selectedShortfallReason == null || _selectedShortfallReason!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.cash_collection_missing_reason_required'.tr())),
        );
      }
      return;
    }

    String? finalNote;
    if (d < 0 && _selectedShortfallReason != null) {
      final reasonText = 'worker.cash_collection_reason_${_selectedShortfallReason!}'.tr();
      final noteText = _shortfallNoteController.text.trim();
      finalNote = 'NEDOPLATEK: $reasonText${noteText.isNotEmpty ? '. Poznámka: $noteText' : ''}';
    }

    final tenantId = widget.ref.read(authNotifierProvider).tenantIdForData;
    final profileId = widget.ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.cash_collection_error'.tr(namedArgs: {'error': 'Missing tenant or profile'})),
          ),
        );
      }
      return;
    }

    try {
      await CashWalletRepository.instance.recordCashCollection(
        taskId: widget.taskId,
        amount: actual,
        tenantId: tenantId,
        profileId: profileId,
        expectedAmount: widget.plannedAmount > 0 ? widget.plannedAmount : null,
        note: finalNote,
      );
      if (widget.completeTaskOnConfirm) {
        await widget.ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
              widget.taskId,
              'completed',
              completedAt: DateTime.now().toUtc(),
              mediaUrls: widget.mediaUrls,
              localPhotoPaths: widget.localPhotoPaths,
              existingMediaUrls: widget.mediaUrls ?? [],
            );
      }
      if (mounted) Navigator.of(context).pop(true);
      widget.onCompleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.cash_collection_confirmed'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.cash_collection_error'.tr(namedArgs: {'error': e.toString()})),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExtraOnly = widget.forceShowForExtraOnly && widget.plannedAmount <= 0;
    final contentText = isExtraOnly
        ? 'worker.cash_collection_extra_only'.tr()
        : 'worker.cash_collection_planned_extra'.tr(namedArgs: {'amount': widget.formattedPlanned});
    final diff = _diff;
    final isShortfall = diff != null && diff < 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Text('worker.cash_collection_confirm_title'.tr()),
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(contentText),
              const SizedBox(height: 16),
              TextField(
                controller: _actualAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                labelText: 'worker.cash_collection_actual_amount'.tr(),
                hintText: 'common.zero_placeholder'.tr(),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (diff != null) ...[
              _buildDiffText(context, diff),
              const SizedBox(height: 12),
            ],
            if (isShortfall) ...[
              Text(
                'worker.cash_collection_missing_reason'.tr(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedShortfallReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                hint: Text('worker.cash_collection_reason_hint'.tr()),
                items: _shortfallReasonKeys.map((key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text('worker.cash_collection_reason_$key'.tr()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedShortfallReason = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shortfallNoteController,
                decoration: InputDecoration(
                  labelText: 'worker.cash_collection_shortfall_note'.tr(),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () async {
                final actual = _parseActualAmount();
                if (actual == null || actual <= 0) return;
                final d = _diff ?? 0;
                if (d < 0 && (_selectedShortfallReason == null || _selectedShortfallReason!.isEmpty)) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('worker.cash_collection_missing_reason_required'.tr())),
                    );
                  }
                  return;
                }
                await _onYes();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('worker.cash_collection_btn_yes'.tr()),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                if (widget.completeTaskOnConfirm) {
                  await widget.ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
                        widget.taskId,
                        'completed',
                        completedAt: DateTime.now().toUtc(),
                        metadataOverlay: {'cash_collection_failed': true},
                        mediaUrls: widget.mediaUrls,
                        localPhotoPaths: widget.localPhotoPaths,
                        existingMediaUrls: widget.mediaUrls ?? [],
                      );
                }
                if (mounted) Navigator.of(context).pop(true);
                widget.onCompleted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('worker.cash_collection_not_collected'.tr())),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade700),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('worker.cash_collection_btn_no'.tr()),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('worker.cash_collection_btn_cancel'.tr()),
            ),
          ],
        ),
      ],
    );
  }
}
