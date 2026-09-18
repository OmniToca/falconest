part of 'package:falconest/features/admin/admin_tasks_screen.dart';

/// Sekce příloh úkolu – stávající URL (klikací odkaz + mazání) a nově vybrané soubory.
/// Používá se v _AddTaskDialog i _EditTaskDialog pro nahrávání fotek/PDF z administrace.
class _TaskAttachmentsSection extends StatelessWidget {
  const _TaskAttachmentsSection({
    required this.existingUrls,
    required this.onRemoveExisting,
    required this.pendingFiles,
    required this.onRemovePending,
    required this.onAddPressed,
    required this.isUploading,
  });

  final List<String> existingUrls;
  final void Function(int index)? onRemoveExisting;
  final List<PlatformFile> pendingFiles;
  final void Function(int index) onRemovePending;
  final VoidCallback? onAddPressed;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final hasExisting = existingUrls.isNotEmpty;
    final hasPending = pendingFiles.isNotEmpty;
    if (!hasExisting && !hasPending && onAddPressed == null) {
      return const SizedBox.shrink();
    }

    return Container(
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
            'tasks.attachments_title'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
          if (onAddPressed != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isUploading ? null : onAddPressed,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text('tasks.add_attachment_button'.tr()),
            ),
          ],
          if (hasExisting || hasPending) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < existingUrls.length; i++) ...[
                  _AttachmentChip(
                    label: '${'tasks.attachments_title'.tr()} ${i + 1}',
                    onTap: () => launchUrl(
                      Uri.parse(existingUrls[i]),
                      mode: LaunchMode.externalApplication,
                    ),
                    onRemove: onRemoveExisting != null
                        ? () => onRemoveExisting!(i)
                        : null,
                    isExisting: true,
                  ),
                ],
                for (var i = 0; i < pendingFiles.length; i++) ...[
                  _AttachmentChip(
                    label: pendingFiles[i].name,
                    onRemove: () => onRemovePending(i),
                    isExisting: false,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Čip jedné přílohy – label, volitelně klik na otevření, křížek pro smazání.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.label,
    this.onTap,
    this.onRemove,
    required this.isExisting,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool isExisting;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label.length > 25 ? '${label.substring(0, 22)}...' : label,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelLarge?.copyWith(
              color: isExisting
                  ? context.colors.primary
                  : context.colors.onSurfaceVariant,
              decoration: isExisting ? TextDecoration.underline : null,
            ),
          ),
        ),
        if (onRemove != null) ...[
          SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: context.colors.error),
          ),
        ],
      ],
    );

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}

/// Read-only blok kontextových informací úkolu („Apple Vibe“).
/// Zobrazuje apartmán, rezervaci, hosty a audit – jen pokud jsou data k dispozici.
/// Rezervace je klikatelná (odkaz) při platném task.reservationId a [onReservationTap].
class _TaskContextSection extends StatelessWidget {
  const _TaskContextSection({required this.task, this.onReservationTap});

  final TaskRow task;
  final void Function(String reservationId)? onReservationTap;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    final dateLoc = context.locale.languageCode;

    // Referenční číslo úkolu – zobrazeno nahoře pro rychlou identifikaci.
    if (task.referenceNumber != null &&
        task.referenceNumber!.trim().isNotEmpty) {
      chips.add(
        _ContextChip(icon: Icons.tag, text: '#${task.referenceNumber!.trim()}'),
      );
    }

    // Apartmán – ikona + lokalizovaný text s názvem bytu.
    final aptName = task.apartmentName;
    if (aptName != null && aptName.trim().isNotEmpty) {
      chips.add(
        _ContextChip(
          icon: Icons.apartment_outlined,
          text: 'admin.task_context_apartment'.tr(
            namedArgs: {'name': aptName.trim()},
          ),
        ),
      );
    }

    // Rezervace – host + termín (jen pokud máme reservationGuestName nebo termín).
    final guest = task.reservationGuestName;
    final start = task.reservationStartDate;
    final end = task.reservationEndDate;
    final hasReservation =
        (guest != null && guest.trim().isNotEmpty) ||
        start != null ||
        end != null;
    if (hasReservation) {
      final parts = <String>[];
      if (guest != null && guest.trim().isNotEmpty) {
        parts.add(guest.trim());
      }
      if (start != null || end != null) {
        final fmt = DateFormat('d.M.', dateLoc);
        final range = start != null && end != null
            ? '${fmt.format(start.toLocal())} – ${fmt.format(end.toLocal())}'
            : (start != null
                  ? fmt.format(start.toLocal())
                  : (end != null ? fmt.format(end.toLocal()) : null));
        if (range != null) {
          parts.add(parts.isEmpty ? range : '($range)');
        }
      }
      if (parts.isNotEmpty) {
        final reservationText = 'admin.task_context_reservation'.tr(
          namedArgs: {'guest': parts.join(' ')},
        );
        final reservationId = task.reservationId;
        final isClickable =
            reservationId != null &&
            reservationId.trim().isNotEmpty &&
            onReservationTap != null;
        chips.add(
          isClickable
              ? _ContextLinkChip(
                  icon: Icons.calendar_today_outlined,
                  text: reservationText,
                  onTap: () => onReservationTap!(reservationId),
                )
              : _ContextChip(
                  icon: Icons.calendar_today_outlined,
                  text: reservationText,
                ),
        );
      }
    }

    // Hosté – počet osob.
    final count = task.reservationGuestCount;
    if (count != null && count > 0) {
      chips.add(
        _ContextChip(
          icon: Icons.people_outline,
          text: 'admin.task_context_guests'.tr(
            namedArgs: {'count': count.toString()},
          ),
        ),
      );
    }

    // Audit – datum vytvoření.
    final createdAt = task.createdAt;
    if (createdAt != null) {
      chips.add(
        _ContextChip(
          icon: Icons.access_time,
          text: 'admin.task_context_created_at'.tr(
            namedArgs: {
              'date': DateFormat(
                'd.M.yyyy HH:mm',
                dateLoc,
              ).format(createdAt.toLocal()),
            },
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Wrap(spacing: 12, runSpacing: AppSpacing.sm, children: chips),
    );
  }
}

/// Read-only přehled odhad vs. skutečnost vs. odchylka – výpočet on-the-fly z existujících polí (bez migrací).
class _TaskTimeProfitabilitySection extends StatelessWidget {
  const _TaskTimeProfitabilitySection({required this.task});

  final TaskRow task;

  @override
  Widget build(BuildContext context) {
    final estimated = _estimateMinutesForAdminProfitability(task);
    final isCompleted = task.completedAt != null;
    final actualMinutes = _actualDurationMinutesForAdmin(task);

    final children = <Widget>[
      _TimeProfitChip(
        icon: Icons.schedule_outlined,
        text: 'tasks.time_estimated'.tr(
          namedArgs: {'minutes': estimated.toString()},
        ),
      ),
    ];
    if (isCompleted) {
      if (actualMinutes != null) {
        children.add(
          _TimeProfitChip(
            icon: Icons.timer_outlined,
            text: 'tasks.time_actual'.tr(
              namedArgs: {'minutes': actualMinutes.toString()},
            ),
          ),
        );
        final diff = actualMinutes - estimated;
        if (diff <= 0) {
          children.add(
            _TimeProfitChip(
              icon: Icons.trending_down,
              text: 'tasks.time_saved'.tr(namedArgs: {'minutes': '${(-diff)}'}),
              accent: context.customColors.success,
            ),
          );
        } else {
          children.add(
            _TimeProfitChip(
              icon: Icons.trending_up,
              text: 'tasks.time_overtime'.tr(
                namedArgs: {'minutes': diff.toString()},
              ),
              accent: context.colors.error,
            ),
          );
        }
      } else {
        children.add(
          _TimeProfitChip(
            icon: Icons.timer_off_outlined,
            text: 'tasks.time_actual_unknown'.tr(),
            accent: context.colors.onSurfaceVariant,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'tasks.time_profitability_title'.tr(),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: children
              .map(
                (w) => ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160),
                  child: w,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Jedna „kartička“ v řádku rentability – ikona + jeden řádek textu.
class _TimeProfitChip extends StatelessWidget {
  const _TimeProfitChip({required this.icon, required this.text, this.accent});

  final IconData icon;
  final String text;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? context.colors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: accent ?? context.colors.onSurfaceVariant,
          ),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              text,
              style: context.textTheme.bodyMedium?.copyWith(
                color: c,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jeden kontextový čip: ikona + lokalizovaný text (emoji jsou již v i18n řetězci).
class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.icon, required this.text});

  final IconData icon;

  /// Plný lokalizovaný text (např. z admin.task_context_apartment.tr(namedArgs: {...})).
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.textTheme.labelLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Klikatelný kontextový čip (odkaz) – primární barva, podtržení, cursor pointer.
/// Používá se pro rezervaci v kontextu úkolu (navigace na detail rezervace).
class _ContextLinkChip extends StatelessWidget {
  const _ContextLinkChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: primary),
              const SizedBox(width: 6),
              Text(
                text,
                style: context.textTheme.labelLarge?.copyWith(
                  color: primary,
                  decoration: TextDecoration.underline,
                  decorationColor: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sekce přiložených fotek u úkolu typu Issue – horizontální seznam miniatur.
///
/// PROČ: Hlášení závad od pracovníků může mít více fotek. Klik otevře dialog
/// s InteractiveViewer (recyklace logiky z detailu účtenky).
class _TaskMediaSection extends StatelessWidget {
  const _TaskMediaSection({required this.mediaUrls});

  final List<String> mediaUrls;

  @override
  Widget build(BuildContext context) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'admin.task_media_attached_photos'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mediaUrls.length,
              separatorBuilder: (_, _) => SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final url = mediaUrls[index];
                return GestureDetector(
                  onTap: () =>
                      WalletDetailModal.showReceiptDialog(context, url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FalconestNetworkImage(
                      imageUrl: url,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 100,
                        height: 100,
                        color: context.colors.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
