import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/utils/signature_service.dart';
import 'package:falconest/features/worker/widgets/signature_pad.dart';

/// Karta + dialog pro podpis hosta u úkolu pracovníka.
///
/// PROČ: Oddělením od [WorkerTaskDetailScreen] držíme master obrazovku čitelnou a
/// soustředíme auditní flow (dialog → PNG → Storage → metadata úkolu) na jednom místě.
/// Loading a SnackBar dávají pracovníkovi jasnou zpětnou vazbu, aby nepředpokládal uložení při chybě sítě.
class WorkerTaskSignatureSection extends ConsumerStatefulWidget {
  const WorkerTaskSignatureSection({
    super.key,
    required this.taskId,
    required this.detail,
  });

  final String taskId;
  final WorkerTaskDetail detail;

  @override
  ConsumerState<WorkerTaskSignatureSection> createState() =>
      _WorkerTaskSignatureSectionState();
}

class _WorkerTaskSignatureSectionState extends ConsumerState<WorkerTaskSignatureSection> {
  /// Běží upload PNG a zápis URL do metadat úkolu — UI je zablokované a ukazuje spinner.
  bool _isSavingSignature = false;

  /// Otevře dialog s [SignaturePad] a po potvrzení vrátí bajty PNG (nebo null při zrušení).
  Future<Uint8List?> _openSignatureCaptureDialog(BuildContext context) {
    return showDialog<Uint8List>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('worker.signature_title'.tr()),
        content: SizedBox(
          width: 520,
          child: SignaturePad(
            onConfirm: (png) => Navigator.of(ctx).pop(png),
          ),
        ),
      ),
    );
  }

  /// Nahraje podpis a propíše `guest_signature_url` do úkolu; při chybě zobrazí SnackBar.
  Future<void> _saveSignatureFromDialogBytes(
    BuildContext context,
    Uint8List signatureBytes,
  ) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('worker.signature_upload_failed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingSignature = true);
    try {
      final signatureUrl = await SignatureService.uploadTaskGuestSignature(
        tenantId: tenantId,
        taskId: widget.taskId,
        pngBytes: signatureBytes,
      );
      if (!context.mounted) return;

      await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
            widget.taskId,
            widget.detail.status,
            metadataOverlay: {'guest_signature_url': signatureUrl},
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.signature_saved'.tr())),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      final isOffline = MutationQueueService.isNetworkError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOffline
                ? 'worker.signature_offline_warning'.tr()
                : 'worker.signature_upload_failed'.tr(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingSignature = false);
      }
    }
  }

  Future<void> _onCaptureSignaturePressed(BuildContext context) async {
    if (_isSavingSignature) return;
    final bytes = await _openSignatureCaptureDialog(context);
    if (bytes == null || !context.mounted) return;
    await _saveSignatureFromDialogBytes(context, bytes);
  }

  Future<void> _showSignaturePreview(BuildContext context, String signatureUrl) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('worker.signature_preview'.tr()),
        content: InteractiveViewer(
          maxScale: 4,
          child: Image.network(
            signatureUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(
              'common.generic_error_user_friendly'.tr(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signatureUrl = widget.detail.metadata?['guest_signature_url']?.toString().trim();
    final hasSignature = signatureUrl != null && signatureUrl.isNotEmpty;

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isSavingSignature,
          child: Opacity(
            opacity: _isSavingSignature ? 0.55 : 1,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.draw_outlined, color: context.colors.primary),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'worker.signature_title'.tr(),
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (hasSignature)
                        IconButton(
                          tooltip: 'worker.signature_preview'.tr(),
                          onPressed: _isSavingSignature
                              ? null
                              : () => _showSignaturePreview(context, signatureUrl),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: widget.detail.isCompleted || _isSavingSignature
                        ? null
                        : () => _onCaptureSignaturePressed(context),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text('worker.signature_capture_button'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isSavingSignature)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'worker.signature_saving'.tr(),
                          style: context.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
