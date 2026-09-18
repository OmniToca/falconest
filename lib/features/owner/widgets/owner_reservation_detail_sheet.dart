import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/owner/providers/owner_reservation_related_tasks_provider.dart';
import 'package:falconest/features/owner/providers/owner_reservations_provider.dart';
import 'package:falconest/features/legal_spain/widgets/reservation_legal_section.dart';
import 'package:falconest/features/owner/widgets/owner_task_detail_dialog.dart';

/// Bottom sheet s detailem rezervace a seznamem souvisejících úkolů ([tasks.reservation_id]).
///
/// PROČ: Majitel vidí provozní kontext pobytu (např. úklid, transfer) bez úpravy rezervace.
class OwnerReservationDetailSheet extends ConsumerWidget {
  const OwnerReservationDetailSheet({super.key, required this.reservation});

  final OwnerReservation reservation;

  /// Otevře modal bottom sheet s detailem.
  static Future<void> show(BuildContext context, OwnerReservation r) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => OwnerReservationDetailSheet(reservation: r),
    );
  }

  static String _guestLabel(OwnerReservation r) {
    final n = (r.guestName ?? '').trim();
    if (n.isEmpty) return 'owner.unknown_guest'.tr();
    return n;
  }

  static String _formatRange(OwnerReservation r, String locale) {
    final df = DateFormat('d.M.yyyy', locale);
    return '${df.format(r.startDate)} – ${df.format(r.endDate)}';
  }

  static String _statusKey(String status) => 'admin.reservation_status_$status';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = context.locale.toString();
    final apt = (reservation.apartmentName ?? '').trim().isEmpty
        ? '–'
        : reservation.apartmentName!.trim();
    final relatedAsync = ref.watch(ownerReservationRelatedTasksProvider(reservation.id));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'owner.reservation_detail_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _guestLabel(reservation),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                apt,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _formatRange(reservation, locale),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(_statusKey(reservation.status).tr()),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if ((reservation.specialRequests ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'owner.reservations_special_requests'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  reservation.specialRequests!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 16),
              ReservationLegalSection(
                reservationId: reservation.id,
                apartmentId: reservation.apartmentId,
                guestPhone: reservation.guestPhone,
                guestEmail: reservation.guestEmail,
              ),
              const SizedBox(height: 24),
              Text(
                'owner.reservation_related_tasks_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              relatedAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Text(
                      'owner.reservation_related_tasks_empty'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    );
                  }
                  return Column(
                    children: tasks.map((t) {
                      return _RelatedTaskTile(
                        task: t,
                        onTap: () {
                          Navigator.of(context).pop();
                          OwnerTaskDetailDialog.show(
                            context,
                            OwnerTaskDetailData(
                              taskId: t.id,
                              title: t.title,
                              taskType: t.taskType,
                              apartmentName: t.apartmentName,
                              scheduledStart: t.scheduledStart ?? t.dueDate,
                              status: t.status,
                              description: t.description.trim().isEmpty
                                  ? null
                                  : t.description,
                              mediaUrls: t.mediaUrls,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Text(
                  'owner.tasks_load_error'.tr(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Jeden řádek souvisejícího úkolu – po tapnutí detail s fotodokumentací.
class _RelatedTaskTile extends StatelessWidget {
  const _RelatedTaskTile({
    required this.task,
    required this.onTap,
  });

  final TaskRow task;
  final VoidCallback onTap;

  static String _typeLabelKey(String taskType) {
    final code =
        (taskType.trim().isEmpty ? 'other' : taskType.toLowerCase()).replaceAll('-', '_');
    return 'admin.task_type_$code';
  }

  static String _statusLabel(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'in_progress' || s == 'probíhá') return 'task_status.in_progress'.tr();
    if (s == 'problem' || s == 'problém') return 'task_status.problem'.tr();
    if (s == 'completed' || s == 'done' || s == 'hotovo') return 'task_status.completed'.tr();
    if (s == 'pending') return 'owner.task_status_new'.tr();
    return 'task_status.assigned'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final title = task.title.trim().isEmpty ? 'admin.task_no_title'.tr() : task.title;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_typeLabelKey(task.taskType).tr()} · ${_statusLabel(task.status)}',
          maxLines: 2,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
