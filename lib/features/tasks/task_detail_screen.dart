// DEPRECATED: Tento soubor je zastaralý a bude smazán. Aktivní UI je v lib/features/worker/.
// Nepoužívat pro nový vývoj – připravujeme přepojení WorkerTaskDetailScreen na Isar.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/services/photo_service.dart';
import 'package:falconest/features/tasks/models/task_detail_data.dart';
import 'package:falconest/features/dashboard/providers/todays_tasks_provider.dart';
import 'package:falconest/features/tasks/providers/task_detail_provider.dart';

/// Barvy konzistentní s worker dashboard.
const _primaryBlue = Color(0xFF1565C0);
const _accentOrange = Color(0xFFE65100);

/// Obrazovka detailu úkolu – načte TaskLocal a ApartmentLocal z Isar.
///
/// Zobrazí název bytu, adresu, kód ke klíčům a velké tlačítko pro zahájení
/// či ukončení úklidu. Při kliknutí se stav uloží do Isar a UI se obnoví.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  /// Isar ID úkolu (z route parametru :id).
  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(taskDetailProvider(taskId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('task_detail.title'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: detailAsync.when(
        data: (data) {
          if (data == null) {
            return _buildNotFound(context);
          }
          return _TaskDetailContent(data: data, taskId: taskId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _buildNotFound(context),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'task_detail.not_found'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text('common.back'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hlavní obsah – karty s detaily a akční tlačítko.
///
/// Používá [TaskDetailData] DTO – bez Isar importů (web-safe).
class _TaskDetailContent extends ConsumerWidget {
  const _TaskDetailContent({
    required this.data,
    required this.taskId,
  });

  final TaskDetailData data;
  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInProgress = data.status == 'in_progress';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Karta s detaily úkolu
          _DetailCard(
            title: 'task_detail.task_info'.tr(),
            children: [
              _DetailRow(
                icon: Icons.access_time,
                label: 'task_detail.scheduled_start'.tr(),
                value: _formatDateTime(data.scheduledStart),
              ),
              _DetailRow(
                icon: Icons.info_outline,
                label: 'task_detail.status'.tr(),
                value: _getStatusLabel(data.status),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Karta s detaily bytu
          _DetailCard(
            title: 'task_detail.apartment_info'.tr(),
            children: [
              _DetailRow(
                icon: Icons.apartment,
                label: 'task_detail.apartment_name'.tr(),
                value: data.apartmentName ?? 'task_detail.no_apartment'.tr(),
              ),
              if (data.apartmentAddress != null && data.apartmentAddress!.isNotEmpty)
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'task_detail.address'.tr(),
                  value: data.apartmentAddress!,
                ),
              if (data.apartmentKeybox != null && data.apartmentKeybox!.isNotEmpty)
                _DetailRow(
                  icon: Icons.key,
                  label: 'task_detail.key_code'.tr(),
                  value: data.apartmentKeybox!,
                ),
            ],
          ),
          const SizedBox(height: 32),

          // Tlačítko VYFOTIT BYT – zobrazí se jen když úklid probíhá
          if (!kIsWeb && isInProgress)
            _TakePhotoButton(
              taskId: taskId,
              hasPhoto: data.photoUrl != null && data.photoUrl!.isNotEmpty,
              onPhotoTaken: () {
                ref.invalidate(taskDetailProvider(taskId));
              },
            ),
          if (!kIsWeb && isInProgress) const SizedBox(height: 16),

          // Velké akční tlačítko – ZAČÍT / UKONČIT ÚKLID
          if (!kIsWeb) ...[
            _ActionButton(
              isInProgress: isInProgress,
              canEndCleaning:
                  isInProgress &&
                  data.photoUrl != null &&
                  data.photoUrl!.isNotEmpty,
              onPressed: () => _onActionPressed(context, ref),
            ),
            if (isInProgress &&
                (data.photoUrl == null || data.photoUrl!.isEmpty)) ...[
              const SizedBox(height: 8),
              Text(
                'task_detail.photo_required_hint'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'dashboard.status_pending'.tr();
      case 'in_progress':
        return 'dashboard.status_in_progress'.tr();
      case 'completed':
        return 'dashboard.status_completed'.tr();
      case 'cancelled':
        return 'dashboard.status_cancelled'.tr();
      default:
        return status;
    }
  }

  Future<void> _onActionPressed(BuildContext context, WidgetRef ref) async {
    final newStatus = data.status == 'in_progress'
        ? 'completed'
        : 'in_progress';
    await updateTaskStatus(taskId: taskId, status: newStatus);

    if (context.mounted) {
      ref.invalidate(taskDetailProvider(taskId));
      ref.invalidate(todaysTasksProvider);
      // Po dokončení úklidu přejdi zpět na Dashboard
      if (newStatus == 'completed') {
        context.go('/worker');
      }
    }
  }
}

/// Karta s titulkem a řádky detailů.
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Řádek s ikonou, popiskem a hodnotou.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tlačítko pro vyfocení bytu – otevře kameru, zkomprimuje a uloží cestu do Isar.
class _TakePhotoButton extends StatelessWidget {
  const _TakePhotoButton({
    required this.taskId,
    required this.hasPhoto,
    required this.onPhotoTaken,
  });

  final int taskId;
  final bool hasPhoto;
  final VoidCallback onPhotoTaken;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () => _onTakePhoto(context),
        icon: Icon(hasPhoto ? Icons.check_circle : Icons.camera_alt),
        label: Text(
          hasPhoto
              ? 'task_detail.btn_photo_taken'.tr()
              : 'task_detail.btn_take_photo'.tr(),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: hasPhoto ? Colors.green : _primaryBlue,
          side: BorderSide(
            color: hasPhoto ? Colors.green : _primaryBlue,
            width: 2,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _onTakePhoto(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final path = await PhotoService.takeAndCompressApartmentPhoto(taskId);

    if (path == null) return;
    if (!context.mounted) return;

    await saveTaskPhotoPath(taskId: taskId, photoPath: path);
    onPhotoTaken();

    scaffoldMessenger?.showSnackBar(
      SnackBar(
        content: Text('task_detail.photo_saved'.tr()),
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// Obří tlačítko pro zahájení či ukončení úklidu.
///
/// [UKONČIT ÚKLID] je odemčeno až po vyfocení bytu (canEndCleaning).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isInProgress,
    required this.canEndCleaning,
    required this.onPressed,
  });

  final bool isInProgress;
  final bool canEndCleaning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isEndDisabled = isInProgress && !canEndCleaning;

    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: isEndDisabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isInProgress ? Colors.red : _accentOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          disabledForegroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Text(
          isInProgress
              ? 'task_detail.btn_end_cleaning'.tr()
              : 'task_detail.btn_start_cleaning'.tr(),
        ),
      ),
    );
  }
}
