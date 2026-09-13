import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/models/task_form_draft.dart';
import 'package:falconest/features/admin/services/task_draft_parse_service.dart';
import 'package:falconest/features/admin/utils/task_draft_clipboard_image.dart';
import 'package:falconest/features/admin/utils/task_draft_image_prepare.dart';

/// Dvoukrokový dialog: vložení WhatsApp textu / screenshotu → AI preview → [TaskFormDraft].
///
/// PROČ samostatný widget: nezatěžuje monolitický admin_tasks_screen; stejný entry point
/// lze později zavolat z Omniboxu nebo dashboardu. Fáze 3: multimodální paste (Cmd+V).
class TaskDraftFromTextDialog extends ConsumerStatefulWidget {
  const TaskDraftFromTextDialog({super.key});

  /// Otevře flow; vrátí draft pro předvyplnění formuláře, nebo null při zrušení.
  static Future<TaskFormDraft?> show(BuildContext context) {
    return showDialog<TaskFormDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TaskDraftFromTextDialog(),
    );
  }

  @override
  ConsumerState<TaskDraftFromTextDialog> createState() =>
      _TaskDraftFromTextDialogState();
}

enum _TaskDraftDialogStep { paste, preview }

class _TaskDraftFromTextDialogState extends ConsumerState<TaskDraftFromTextDialog> {
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  _TaskDraftDialogStep _step = _TaskDraftDialogStep.paste;
  TaskFormDraft? _draft;
  String? _selectedApartmentId;
  String? _selectedClientId;
  String? _selectedServiceId;
  bool _isAnalyzing = false;
  bool _isPreparingImage = false;
  String? _errorCode;

  /// Komprimovaný JPEG pro náhled + odeslání na Edge.
  Uint8List? _imagePreviewBytes;
  String? _imageBase64;
  String? _imageMimeType;

  TaskDraftClipboardImageSubscription? _clipboardSub;

  @override
  void initState() {
    super.initState();
    _clipboardSub = listenForTaskDraftClipboardImages(_onClipboardImage);
  }

  @override
  void dispose() {
    _clipboardSub?.cancel();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onClipboardImage(Uint8List bytes, String mimeType) async {
    if (_step != _TaskDraftDialogStep.paste || _isAnalyzing) return;
    await _setImageFromBytes(bytes);
  }

  Future<void> _pickImageFile() async {
    if (_isAnalyzing || _isPreparingImage) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) return;
    await _setImageFromBytes(Uint8List.fromList(bytes));
  }

  Future<void> _setImageFromBytes(Uint8List bytes) async {
    setState(() {
      _isPreparingImage = true;
      _errorCode = null;
    });
    try {
      final prepared = await TaskDraftImagePrepare.prepare(bytes);
      if (!mounted) return;
      setState(() {
        _imagePreviewBytes = prepared.previewBytes;
        _imageBase64 = prepared.base64;
        _imageMimeType = prepared.mimeType;
        _isPreparingImage = false;
      });
    } catch (e, st) {
      AppLogger.error('TaskDraftFromTextDialog: příprava obrázku selhala', e, st);
      if (!mounted) return;
      setState(() {
        _isPreparingImage = false;
        _errorCode = e.toString().contains('image_too_large')
            ? 'TASK_DRAFT_IMAGE_TOO_LARGE'
            : 'TASK_DRAFT_IMAGE_FAILED';
      });
    }
  }

  void _clearImage() {
    setState(() {
      _imagePreviewBytes = null;
      _imageBase64 = null;
      _imageMimeType = null;
    });
  }

  Future<void> _runAnalyze() async {
    final text = _textController.text.trim();
    final hasImage = _imageBase64 != null && _imageBase64!.isNotEmpty;
    if (text.isEmpty && !hasImage) {
      setState(() => _errorCode = 'TASK_DRAFT_EMPTY_TEXT');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorCode = null;
    });

    try {
      final auth = ref.read(authNotifierProvider);
      final draft = await TaskDraftParseService.parseFromText(
        rawText: text,
        locale: auth.state.languageCode,
        tenantTimezone: auth.state.effectiveTenantTimezone,
        imageBase64: _imageBase64,
        imageMimeType: _imageMimeType,
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _selectedApartmentId = draft.apartmentId;
        _selectedClientId = draft.clientId;
        _selectedServiceId = draft.serviceId;
        _step = _TaskDraftDialogStep.preview;
        _isAnalyzing = false;
      });
    } on TaskDraftParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCode = e.code;
        _isAnalyzing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorCode = 'TASK_DRAFT_UNKNOWN';
        _isAnalyzing = false;
      });
    }
  }

  String _errorMessage(String? code) {
    if (code == null) return '';
    final key = 'admin.task_draft_error_$code';
    final translated = key.tr();
    if (translated != key) return translated;
    return 'admin.task_draft_error_generic'.tr();
  }

  TaskFormDraft _buildResultDraft() {
    final base = _draft!;
    return base.copyWith(
      apartmentId: _selectedApartmentId,
      clientId: _selectedClientId,
      serviceId: _selectedServiceId,
      rawSourceText: _textController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: context.colors.primary),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _step == _TaskDraftDialogStep.paste
                          ? 'admin.task_draft_paste_title'.tr()
                          : 'admin.task_draft_preview_title'.tr(),
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'common.close'.tr(),
                    onPressed: _isAnalyzing
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                _step == _TaskDraftDialogStep.paste
                    ? 'admin.task_draft_paste_hint_multimodal'.tr()
                    : 'admin.task_draft_preview_hint'.tr(),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Expanded(
                child: _step == _TaskDraftDialogStep.paste
                    ? _buildPasteStep(context)
                    : _buildPreviewStep(context),
              ),
              if (_errorCode != null) ...[
                SizedBox(height: AppSpacing.sm),
                Text(
                  _errorMessage(_errorCode),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.md),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasteStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            focusNode: _textFocusNode,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'admin.task_draft_paste_placeholder'.tr(),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'admin.task_draft_image_section'.tr(),
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        if (_imagePreviewBytes != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _imagePreviewBytes!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  tooltip: 'admin.task_draft_image_remove'.tr(),
                  onPressed: _isAnalyzing || _isPreparingImage
                      ? null
                      : _clearImage,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: _isAnalyzing || _isPreparingImage ? null : _pickImageFile,
            icon: _isPreparingImage
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.primary,
                    ),
                  )
                : const Icon(Icons.image_outlined, size: 20),
            label: Text(
              _isPreparingImage
                  ? 'admin.task_draft_image_preparing'.tr()
                  : 'admin.task_draft_image_add'.tr(),
            ),
          ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'admin.task_draft_image_paste_hint'.tr(),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewStep(BuildContext context) {
    final draft = _draft;
    if (draft == null) return const SizedBox.shrink();

    final dateLabel = draft.scheduledStart != null
        ? (() {
            final dt = draft.scheduledStart!;
            final wall = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
            return DateFormat('dd.MM.yyyy HH:mm').format(wall);
          })()
        : '—';

    final modeLabel = switch (draft.taskMode) {
      TaskFormDraftMode.apartmentBound => 'tasks.form_mode_apartment'.tr(),
      TaskFormDraftMode.externalService => 'tasks.form_mode_external'.tr(),
      TaskFormDraftMode.unknown => 'admin.task_draft_mode_unknown'.tr(),
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (draft.warnings.isNotEmpty)
            _WarningBanner(warnings: draft.warnings),
          _PreviewRow(
            label: 'admin.task_draft_field_mode'.tr(),
            value: modeLabel,
          ),
          _PreviewRow(
            label: 'admin.task_field_title'.tr(),
            value: draft.title?.trim().isNotEmpty == true ? draft.title! : '—',
          ),
          _PreviewRow(
            label: 'admin.task_field_description'.tr(),
            value: draft.description?.trim().isNotEmpty == true
                ? draft.description!
                : '—',
          ),
          _PreviewRow(
            label: 'admin.task_draft_field_datetime'.tr(),
            value: dateLabel,
          ),
          _PreviewRow(
            label: 'admin.task_draft_field_duration'.tr(),
            value: draft.durationMinutes != null
                ? 'admin.task_draft_duration_minutes'.tr(
                    namedArgs: {'minutes': '${draft.durationMinutes}'},
                  )
                : '—',
          ),
          _PreviewRow(
            label: 'admin.task_draft_field_price'.tr(),
            value: draft.price != null
                ? 'admin.task_draft_price_value'.tr(
                    namedArgs: {
                      'amount': draft.price!.toStringAsFixed(
                        draft.price! == draft.price!.roundToDouble() ? 0 : 2,
                      ),
                    },
                  )
                : '—',
          ),
          _PreviewRow(
            label: 'admin.task_draft_field_payment'.tr(),
            value: draft.isCashPayment == null
                ? '—'
                : (draft.isCashPayment!
                    ? 'tasks.form_payment_cash'.tr()
                    : 'tasks.form_payment_invoice'.tr()),
          ),
          if (draft.taskMode != TaskFormDraftMode.externalService) ...[
            SizedBox(height: AppSpacing.sm),
            Text(
              'admin.task_draft_field_apartment'.tr(),
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            if (draft.apartmentCandidates.isEmpty)
              Text(
                draft.apartmentId != null
                    ? 'admin.task_draft_apartment_resolved'.tr()
                    : 'admin.task_draft_apartment_missing'.tr(),
                style: context.textTheme.bodyMedium,
              )
            else
              DropdownButtonFormField<String?>(
                initialValue: _selectedApartmentId,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'admin.task_draft_apartment_pick'.tr(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('admin.task_draft_apartment_none'.tr()),
                  ),
                  ...draft.apartmentCandidates.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(
                        c.subtitle != null && c.subtitle!.isNotEmpty
                            ? '${c.label} (${c.subtitle})'
                            : c.label,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedApartmentId = v),
              ),
            if (draft.hasLowConfidenceApartmentMatch &&
                _selectedApartmentId != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'admin.task_draft_apartment_low_confidence'.tr(),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.customColors.warning,
                  ),
                ),
              ),
          ],
          if (draft.taskMode == TaskFormDraftMode.externalService ||
              draft.clientCandidates.isNotEmpty ||
              (draft.clientId?.isNotEmpty ?? false)) ...[
            SizedBox(height: AppSpacing.sm),
            Text(
              'admin.task_draft_field_client'.tr(),
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            if (draft.clientCandidates.isEmpty)
              Text(
                draft.clientId != null && draft.clientId!.isNotEmpty
                    ? 'admin.task_draft_client_resolved'.tr()
                    : 'admin.task_draft_client_missing'.tr(),
                style: context.textTheme.bodyMedium,
              )
            else
              DropdownButtonFormField<String?>(
                initialValue: _selectedClientId,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'admin.task_draft_client_pick'.tr(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('admin.task_draft_client_none'.tr()),
                  ),
                  ...draft.clientCandidates.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(
                        c.subtitle != null && c.subtitle!.isNotEmpty
                            ? '${c.label} (${c.subtitle})'
                            : c.label,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedClientId = v),
              ),
          ],
          SizedBox(height: AppSpacing.sm),
          Text(
            'admin.task_draft_field_service'.tr(),
            style: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          if (draft.serviceCandidates.isEmpty)
            Text(
              draft.hasMatchedService
                  ? 'admin.task_draft_service_resolved'.tr()
                  : 'admin.task_draft_service_missing'.tr(),
              style: context.textTheme.bodyMedium,
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: _selectedServiceId,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'admin.task_draft_service_pick'.tr(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('admin.task_draft_service_none'.tr()),
                ),
                ...draft.serviceCandidates.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(
                      c.subtitle != null && c.subtitle!.isNotEmpty
                          ? '${c.label} (${c.subtitle})'
                          : c.label,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedServiceId = v),
            ),
          if (draft.customLocationHint?.isNotEmpty == true)
            _PreviewRow(
              label: 'admin.task_draft_field_location'.tr(),
              value: draft.customLocationHint!,
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (_step == _TaskDraftDialogStep.paste) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isAnalyzing ? null : () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
          SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: (_isAnalyzing || _isPreparingImage) ? null : _runAnalyze,
            icon: _isAnalyzing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onPrimary,
                    ),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _isAnalyzing
                  ? 'admin.task_draft_analyzing'.tr()
                  : 'admin.task_draft_analyze'.tr(),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => setState(() {
            _step = _TaskDraftDialogStep.paste;
            _errorCode = null;
          }),
          child: Text('admin.task_draft_back'.tr()),
        ),
        SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildResultDraft()),
          child: Text('admin.task_draft_open_form'.tr()),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(value, style: context.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final messages = warnings
        .map((w) {
          final key = 'admin.task_draft_warning_$w';
          final t = key.tr();
          return t != key ? t : null;
        })
        .whereType<String>()
        .toList();

    if (messages.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.customColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.customColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages
            .map(
              (m) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: context.customColors.warning,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(m, style: context.textTheme.bodySmall)),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
