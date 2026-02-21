
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/features/worker/providers/worker_detail_provider.dart';

/// Barvy konzistentní s Worker Dashboard.
const _primaryBlue = Color(0xFF1565C0);
const _accentGreen = Color(0xFF2E7D32);

/// Obrazovka detailu úkolu v Worker App – Execution Mode.
///
/// Zobrazuje název bytu, adresu s tlačítkem pro mapy, keybox kód,
/// instrukce a akce: zahájit práci, nahrát fotku, dokončit.
class WorkerTaskDetailScreen extends ConsumerStatefulWidget {
  const WorkerTaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<WorkerTaskDetailScreen> createState() => _WorkerTaskDetailScreenState();
}

class _WorkerTaskDetailScreenState extends ConsumerState<WorkerTaskDetailScreen> {
  /// Lokálně vybraná fotka – zatím bez uploadu do Supabase Storage.
  XFile? _pickedPhoto;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(workerTaskDetailProvider(widget.taskId));
    final statusState = ref.watch(workerTaskStatusNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('task_detail.title'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return _buildNotFound(context);
          }
          return _TaskViewDelegator(
            detail: detail,
            statusState: statusState,
            pickedPhoto: _pickedPhoto,
            onStartWork: () => _updateStatus(detail.id, 'in_progress'),
            onFinish: () => _finishAndNavigate(detail.id),
            onPickPhoto: _pickPhoto,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildNotFound(context),
      ),
    );
  }

  Future<void> _updateStatus(String taskId, String status) async {
    await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(taskId, status);
  }

  /// Po kliknutí na Dokončit nastaví stav na completed a obrazovku zavře (State Machine: Zahájit → Dokončit → Zavřít).
  Future<void> _finishAndNavigate(String taskId) async {
    await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(taskId, 'completed');
    if (context.mounted) {
      context.pop();
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (xFile != null && mounted) {
        setState(() => _pickedPhoto = xFile);
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('WorkerTaskDetail: IMAGE PICK ERROR: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error_with_message'.tr(namedArgs: {'message': '$e'}))),
        );
      }
    }
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'worker.task_detail_not_found'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/worker'),
              icon: const Icon(Icons.arrow_back),
              label: Text('common.back'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delegátor: podle task_type vybere konkrétní View (Transfer, CheckIn, Issue, Cleaning, Default).
/// Odstraňuje anti-pattern jednoho obřího widgetu s if/else – každý typ úkolu má vlastní View pro budoucí rozdílné UI.
class _TaskViewDelegator extends StatelessWidget {
  const _TaskViewDelegator({
    required this.detail,
    required this.statusState,
    required this.pickedPhoto,
    required this.onStartWork,
    required this.onFinish,
    required this.onPickPhoto,
  });

  final WorkerTaskDetail detail;
  final AsyncValue<void> statusState;
  final XFile? pickedPhoto;
  final VoidCallback onStartWork;
  final VoidCallback onFinish;
  final VoidCallback onPickPhoto;

  static bool _isTransfer(String t) =>
      t.contains('transfer_in') || t.contains('transfer_out') || t.contains('transfer');
  static bool _isCheckIn(String t) =>
      t.contains('check_in') || t.contains('check_out') || t.contains('check');
  static bool _isIssue(String t) => t.contains('issue') || t.contains('závada');
  static bool _isCleaning(String t) => t.contains('cleaning') || t.contains('úklid');
  static bool _isMaterial(String t) => t.contains('material');

  @override
  Widget build(BuildContext context) {
    final isLoading = statusState.isLoading;
    final t = detail.taskType.toLowerCase();
    if (_isTransfer(t)) {
      return TransferTaskView(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        pickedPhoto: pickedPhoto,
      );
    }
    if (_isCheckIn(t)) {
      return CheckInTaskView(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        pickedPhoto: pickedPhoto,
      );
    }
    if (_isIssue(t)) {
      return IssueTaskView(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        pickedPhoto: pickedPhoto,
      );
    }
    if (_isCleaning(t)) {
      return CleaningTaskView(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        pickedPhoto: pickedPhoto,
      );
    }
    return DefaultTaskView(
      detail: detail,
      isLoading: isLoading,
      onStartWork: onStartWork,
      onFinish: onFinish,
      onPickPhoto: onPickPhoto,
      pickedPhoto: pickedPhoto,
      isMaterial: _isMaterial(t),
    );
  }
}

/// View pro úkoly typu Transfer – předání/převzetí bytu.
/// Oddělená třída kvůli budoucímu odlišení UI (např. kontakty, checklist předání, fotodokumentace).
class TransferTaskView extends StatelessWidget {
  const TransferTaskView({
    super.key,
    required this.detail,
    required this.isLoading,
    required this.onStartWork,
    required this.onFinish,
    required this.onPickPhoto,
    this.pickedPhoto,
  });

  final WorkerTaskDetail detail;
  final bool isLoading;
  final VoidCallback onStartWork;
  final VoidCallback onFinish;
  final VoidCallback onPickPhoto;
  final XFile? pickedPhoto;

  @override
  Widget build(BuildContext context) {
    return _TaskDetailLayout(
      detail: detail,
      pickedPhoto: pickedPhoto,
      actionArea: _ActionArea(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        startKey: 'worker.task_detail_start_transfer',
        finishKey: 'worker.task_detail_finish_transfer',
        showPhotoInProgress: false,
        workflowTypeKey: 'worker.task_detail_workflow_type_transfer',
      ),
    );
  }
}

/// View pro úkoly Check-in / Check-out – vstup do bytu, předání klíčů.
/// Oddělená třída pro budoucí rozšíření (např. stav bytu, podpis, čas příchodu/odchodu).
class CheckInTaskView extends StatelessWidget {
  const CheckInTaskView({
    super.key,
    required this.detail,
    required this.isLoading,
    required this.onStartWork,
    required this.onFinish,
    required this.onPickPhoto,
    this.pickedPhoto,
  });

  final WorkerTaskDetail detail;
  final bool isLoading;
  final VoidCallback onStartWork;
  final VoidCallback onFinish;
  final VoidCallback onPickPhoto;
  final XFile? pickedPhoto;

  @override
  Widget build(BuildContext context) {
    return _TaskDetailLayout(
      detail: detail,
      pickedPhoto: pickedPhoto,
      actionArea: _ActionArea(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        startKey: 'worker.task_detail_start_work',
        finishKey: 'worker.task_detail_finish',
        showPhotoInProgress: false,
        workflowTypeKey: 'worker.task_detail_workflow_type_checkin',
      ),
    );
  }
}

/// View pro úkoly typu Závada/Oprava – hlášení a vyřešení problému.
/// Oddělená třída pro budoucí specifika (kategorie závady, náhradní díly, eskalační kontakty).
class IssueTaskView extends StatelessWidget {
  const IssueTaskView({
    super.key,
    required this.detail,
    required this.isLoading,
    required this.onStartWork,
    required this.onFinish,
    required this.onPickPhoto,
    this.pickedPhoto,
  });

  final WorkerTaskDetail detail;
  final bool isLoading;
  final VoidCallback onStartWork;
  final VoidCallback onFinish;
  final VoidCallback onPickPhoto;
  final XFile? pickedPhoto;

  @override
  Widget build(BuildContext context) {
    return _TaskDetailLayout(
      detail: detail,
      pickedPhoto: pickedPhoto,
      actionArea: _ActionArea(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        startKey: 'worker.task_detail_start_repair',
        finishKey: 'worker.task_detail_resolved',
        showPhotoInProgress: false,
        workflowTypeKey: 'worker.task_detail_workflow_type_issue',
      ),
    );
  }
}

/// View pro úkoly typu Úklid – čištění bytu po odchodu hosta.
/// Oddělená třída pro budoucí rozšíření (checklist místností, fotodokumentace před/po, hodnocení).
class CleaningTaskView extends StatelessWidget {
  const CleaningTaskView({
    super.key,
    required this.detail,
    required this.isLoading,
    required this.onStartWork,
    required this.onFinish,
    required this.onPickPhoto,
    this.pickedPhoto,
  });

  final WorkerTaskDetail detail;
  final bool isLoading;
  final VoidCallback onStartWork;
  final VoidCallback onFinish;
  final VoidCallback onPickPhoto;
  final XFile? pickedPhoto;

  @override
  Widget build(BuildContext context) {
    return _TaskDetailLayout(
      detail: detail,
      pickedPhoto: pickedPhoto,
      actionArea: _ActionArea(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        startKey: 'worker.task_detail_start_work',
        finishKey: 'worker.task_detail_finish',
        showPhotoInProgress: true,
        workflowTypeKey: 'worker.task_detail_workflow_type_cleaning',
      ),
    );
  }
}

/// View pro ostatní typy úkolů (Materiál, Jiné) – jednotné „Zahájit / Dokončit“ s volitelným DOPLNĚNO pro materiál.
/// Oddělená třída umožní později odlišit doplňování zásob od generických úkolů.
class DefaultTaskView extends StatelessWidget {
  const DefaultTaskView({
    super.key,
    required this.detail,
    required this.isLoading,
    required this.onStartWork,
    required this.onFinish,
    required this.onPickPhoto,
    this.pickedPhoto,
    this.isMaterial = false,
  });

  final WorkerTaskDetail detail;
  final bool isLoading;
  final VoidCallback onStartWork;
  final VoidCallback onFinish;
  final VoidCallback onPickPhoto;
  final XFile? pickedPhoto;
  final bool isMaterial;

  @override
  Widget build(BuildContext context) {
    return _TaskDetailLayout(
      detail: detail,
      pickedPhoto: pickedPhoto,
      actionArea: _ActionArea(
        detail: detail,
        isLoading: isLoading,
        onStartWork: onStartWork,
        onFinish: onFinish,
        onPickPhoto: onPickPhoto,
        startKey: 'worker.task_detail_start_work',
        finishKey: isMaterial ? 'worker.task_detail_replenished' : 'worker.task_detail_finish',
        showPhotoInProgress: false,
        workflowTypeKey: isMaterial
            ? 'worker.task_detail_workflow_type_material'
            : 'worker.task_detail_workflow_type_task',
      ),
    );
  }
}

/// Sdílený layout detailu úkolu: header, adresa, keybox, instrukce, náhled fotky a předaná akční oblast.
/// Každý TaskView ho skládá se svou vlastní _ActionArea (různé labely a workflow).
class _TaskDetailLayout extends StatelessWidget {
  const _TaskDetailLayout({
    required this.detail,
    required this.pickedPhoto,
    required this.actionArea,
  });

  final WorkerTaskDetail detail;
  final XFile? pickedPhoto;
  final Widget actionArea;

  static Future<void> _openMaps(String? address) async {
    final query = (address ?? '').trim();
    if (query.isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = detail.apartmentAddress ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(detail: detail),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'task_detail.address'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address.isEmpty ? '—' : address,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: address.isEmpty ? null : () => _openMaps(address),
                    tooltip: 'worker.task_detail_open_maps'.tr(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'worker.task_detail_keybox'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (detail.keybox ?? '').trim().isEmpty
                        ? 'worker.task_detail_keybox_not_set'.tr()
                        : detail.keybox!,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: (detail.keybox ?? '').trim().isEmpty
                          ? Colors.grey.shade500
                          : _primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (detail.description.trim().isNotEmpty ||
              (detail.ownerNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'worker.task_detail_instructions'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (detail.ownerNotes ?? '').trim().isNotEmpty
                          ? detail.ownerNotes!
                          : detail.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (pickedPhoto != null) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<dynamic>(
                future: pickedPhoto!.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data! as Uint8List,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  }
                  return SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Center(
                      child: snapshot.hasError
                          ? Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400)
                          : const CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 32),
          actionArea,
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final WorkerTaskDetail detail;

  IconData _iconForTaskType(String type) {
    final t = type.toLowerCase();
    if (t.contains('cleaning') || t.contains('úklid')) return Icons.cleaning_services_rounded;
    if (t.contains('transfer')) return Icons.directions_car_rounded;
    if (t.contains('check_in') || t.contains('check_out')) return Icons.key_rounded;
    return Icons.task_alt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconForTaskType(detail.taskType),
            size: 32,
            color: _primaryBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.apartmentName ?? '—',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail.title,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dynamické akční tlačítka podle stavu (State Machine: pending → Zahájit, in_progress → Dokončit).
/// Labely a typ workflow předávají jednotlivé TaskView (startKey, finishKey, workflowTypeKey, showPhotoInProgress).
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.detail,
    required this.isLoading,
    required this.onStartWork,
    required this.onFinish,
    required this.onPickPhoto,
    required this.startKey,
    required this.finishKey,
    required this.showPhotoInProgress,
    required this.workflowTypeKey,
  });

  final WorkerTaskDetail detail;
  final bool isLoading;
  final VoidCallback onStartWork;
  final VoidCallback onFinish;
  final VoidCallback onPickPhoto;
  final String startKey;
  final String finishKey;
  final bool showPhotoInProgress;
  final String workflowTypeKey;

  /// Indikátor aktuálního typu workflow obrazovky – těsně nad stavem workflow (i18n přes workflowTypeKey).
  Widget _buildActiveWorkflowIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '${'worker.task_detail_active_page_label'.tr()} ${workflowTypeKey.tr()}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  /// Mapování hodnoty stavu z DB na existující i18n klíč (nikdy nelep klíč z surové hodnoty typu "Nový").
  String _getWorkflowStatusTranslationKey(String status) {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'nový':
      case 'pending':
        return 'worker.task_detail_status_pending';
      case 'assigned':
      case 'přiřazeno':
        return 'worker.task_detail_status_assigned';
      case 'draft':
      case 'koncept':
        return 'worker.task_detail_status_draft';
      case 'in_progress':
      case 'probíhá':
      case 'in progress':
        return 'worker.task_detail_status_in_progress';
      case 'completed':
      case 'dokončeno':
        return 'worker.task_detail_status_completed';
      case 'done':
      case 'hotovo':
        return 'worker.task_detail_status_done';
      case 'cancelled':
      case 'zrušeno':
      case 'canceled':
        return 'worker.task_detail_status_cancelled';
      default:
        return 'worker.task_detail_status_unknown';
    }
  }

  /// Vykreslení aktuálního stavu workflow s využitím dynamických i18n klíčů (žádný hardcodovaný text).
  Widget _buildWorkflowIndicator() {
    final statusKey = _getWorkflowStatusTranslationKey(detail.status);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '${'worker.task_detail_workflow_label'.tr()} ${statusKey.tr()}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  /// Společný blok indikátorů: aktivní workflow typ + stav workflow (State Machine: Zahájit → Dokončit → Zavřít).
  Widget _buildWorkflowIndicators() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActiveWorkflowIndicator(),
        _buildWorkflowIndicator(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (detail.isCompleted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWorkflowIndicators(),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: _accentGreen, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'dashboard.status_completed'.tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _accentGreen),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (detail.canStart) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWorkflowIndicators(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onStartWork,
              style: FilledButton.styleFrom(
                backgroundColor: _accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? Text('worker.task_detail_status_updating'.tr())
                  : Text(startKey.tr()),
            ),
          ),
        ],
      );
    }

    // In progress: jedno primární tlačítko (label z finishKey); u úklidu navíc foto
    final showPhoto = showPhotoInProgress;
    final primaryButton = SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onFinish,
        style: FilledButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? Text('worker.task_detail_status_updating'.tr())
            : Text(finishKey.tr()),
      ),
    );

    if (showPhoto) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWorkflowIndicators(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onPickPhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text('worker.task_detail_upload_photo'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          primaryButton,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWorkflowIndicators(),
        primaryButton,
      ],
    );
  }
}
