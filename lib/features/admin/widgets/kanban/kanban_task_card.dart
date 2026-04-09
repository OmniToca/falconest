import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/models/task_custom_tag.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/widgets/kanban/kanban_shared.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Pilulka „hodiny + časové okno“ na Kanban kartě úkolu.
///
/// PROČ: [Wrap] v úzkém sloupci dává dítěti konečnou max šířku; [LayoutBuilder] ji předá do [Row] a
/// [Expanded] kolem [Text] umožní `ellipsis` bez přetečení. Při neomezené šířci se [Expanded] nepoužije,
/// aby widget byl bezpečný i mimo Kanban (horizontální scroll apod.). [crossAxisAlignment.center] srovná
/// ikonu s jednořádkovým textem; mezera jen [AppSpacing.xs] (4 px).
class KanbanTaskTimePill extends StatelessWidget {
  const KanbanTaskTimePill({super.key, required this.timeWindowText});

  final String timeWindowText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'admin.task_kanban_time_a11y'.tr(
        namedArgs: {'window': timeWindowText},
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelStyle = context.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: context.colors.onSurface,
          );
          final timeIcon = Icon(
            Icons.schedule,
            size: 10,
            color: context.colors.onSurfaceVariant,
          );

          // PROČ kontroly hasBoundedWidth: [Expanded] uvnitř [Row] vyžaduje, aby rodič předal
          // konečnou max šířku (jinak Flutter při layoutu spadne). V Kanbanu ji [Wrap] dává vždy;
          // při znovupoužití pilulky v horizontálním [ListView], [SingleChildScrollView] s osou X
          // nebo jiném scrollovacím řádku ale může být šířka v horizontální ose neomezená –
          // pak použijeme [Row] s mainAxisSize.min a prostý [Text] bez [Expanded].
          final Widget rowChild;
          if (constraints.hasBoundedWidth) {
            rowChild = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                timeIcon,
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    timeWindowText,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          } else {
            rowChild = Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                timeIcon,
                SizedBox(width: AppSpacing.xs),
                Text(
                  timeWindowText,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: rowChild,
          );
        },
      ),
    );
  }
}

/// Obsah karty – sdílený pro feedback při táhnutí. Kompaktní layout shodný s [TaskCard].
class KanbanTaskCardContent extends StatelessWidget {
  const KanbanTaskCardContent({super.key, required this.task});

  final TaskRow task;

  @override
  Widget build(BuildContext context) {
    // Auditing: Zámek – při drag feedbacku zobrazíme ikonu u dokončených
    final isLocked = normalizeToSystemStatus(task.status) == 'completed';
    final assignedText = task.assignedToName != null
        ? 'admin.task_assigned'.tr(namedArgs: {'name': task.assignedToName!})
        : 'admin.task_unassigned'.tr();
    final timeWindowText = kanbanTaskTimeWindowText(task);
    final statusColor = TaskCard.statusColor(
      normalizeToSystemStatus(task.status),
    );
    final customTags = TaskCustomTag.listFromMetadata(task.metadata);
    // Stejná hierarchie jako TaskCard (bez ikony koše – drag feedback)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. řádek – kontext: referenční číslo (pokud existuje) + přeložený název kategorie + zámeček (dokončené)
        Row(
          children: [
            if (task.referenceNumber != null &&
                task.referenceNumber!.trim().isNotEmpty) ...[
              Text(
                '#${task.referenceNumber!.trim()}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                taskTypeLabelKey(task.taskType).tr(),
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            if (isLocked)
              Icon(Icons.lock, size: 16, color: context.colors.outline),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        // 2. řádek – hlavní nadpis (externí: custom_title modře; apartmán: title/apartmentName)
        Builder(
          builder: (context) {
            final isExternal = (task.apartmentId.trim().isEmpty);
            final displayTitle = isExternal
                ? (task.customTitle?.trim().isNotEmpty == true
                      ? task.customTitle!
                      : task.title.trim().isNotEmpty
                      ? task.title
                      : 'admin.task_no_title'.tr())
                : (task.title.trim().isNotEmpty
                      ? task.title
                      : (task.apartmentName?.trim().isNotEmpty == true
                            ? task.apartmentName!
                            : 'admin.task_no_title'.tr()));
            return Text(
              displayTitle,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                // Externí úkol: zvýraznění přes sémantickou „info“ barvu tématu (odpovídá dřívější modré).
                color: isExternal
                    ? context.customColors.info
                    : context.colors.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        if (customTags.isNotEmpty) ...[
          SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: customTags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: t.color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.label,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: TaskCustomTag.readableForegroundOn(t.color),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        SizedBox(height: AppSpacing.xs),
        // 3. řádek – lokace: externí = custom_location; apartmán = apartmentName (jen pokud se liší od nadpisu)
        Builder(
          builder: (context) {
            final isExternal = (task.apartmentId.trim().isEmpty);
            if (isExternal &&
                task.customLocation != null &&
                task.customLocation!.trim().isNotEmpty) {
              return Text(
                task.customLocation!,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
            if (!isExternal &&
                task.apartmentName != null &&
                task.apartmentName!.trim().isNotEmpty &&
                task.title.trim().isNotEmpty) {
              return Text(
                task.apartmentName!,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Text(
          assignedText,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                TaskCard.statusLabel(normalizeToSystemStatus(task.status)),
                style: context.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            KanbanTaskTimePill(timeWindowText: timeWindowText),
            if (task.mediaUrls.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 14,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '(${task.mediaUrls.length})',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Jedna karta úkolu: kontext (kategorie) → hlavní nadpis (task.title) → lokace, přiřazení → pilulky. Celá karta klikatelná + ikona koše.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.categoriesByCode,
    required this.onEdit,
    required this.onDelete,
    this.isFinanciallyLocked = false,
    this.selectionMode = false,
    this.isSelected = false,
    required this.onToggleSelect,
    required this.onLongPressSelect,
  });

  final TaskRow task;
  final Map<String, TaskCategoryModel> categoriesByCode;
  final ValueChanged<TaskRow> onEdit;
  final ValueChanged<TaskRow> onDelete;

  /// true = úkol má výplaty nebo provize – zámek a skrytí koše (ochrana účetnictví).
  final bool isFinanciallyLocked;

  /// Režim výběru více karet – tap přepíná zaškrtnutí místo otevření detailu.
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onLongPressSelect;

  /// Barva podle systémového statusu (pending, assigned, in_progress, completed, problem).
  static Color statusColor(String systemStatus) =>
      kanbanTaskStatusColor(systemStatus);

  static String statusLabel(String systemStatus) =>
      localizedTaskStatus(systemStatus);

  @override
  Widget build(BuildContext context) {
    // Auditing: Zámek – dokončené úkoly nebo finančně vypořádané (výplaty/provize) – ikona zámku, skrytí koše.
    final isLocked =
        isFinanciallyLocked ||
        normalizeToSystemStatus(task.status) == 'completed';
    final assigned = task.assignedToName != null
        ? 'admin.task_assigned'.tr(namedArgs: {'name': task.assignedToName!})
        : 'admin.task_unassigned'.tr();
    final timeWindowText = kanbanTaskTimeWindowText(task);
    final typeIcon = TaskVisuals.getIcon(
      task.taskType,
      categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null,
    );
    // Dynamické pastelové pozadí podle typu úkolu – kritické pro UX dispečinku (odpovídá horním filtrům).
    final cardColor = TaskVisuals.getBackgroundColor(
      task.taskType,
      categoriesByCode: categoriesByCode.isNotEmpty ? categoriesByCode : null,
    );

    // Celá karta je klikatelná – prémiová dekorace z tématu, barva pozadí stále z kategorií úkolů (DB).
    final radius = BorderRadius.circular(AppSpacing.md);
    final cardDecoration = premiumCardDecoration(context).copyWith(color: cardColor);

    final customTags = TaskCustomTag.listFromMetadata(task.metadata);

    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selectionMode ? onToggleSelect : () => onEdit(task),
          onLongPress: selectionMode ? null : onLongPressSelect,
          borderRadius: radius,
          child: Ink(
            decoration: cardDecoration,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => onToggleSelect(),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. řádek – kontext: referenční číslo (pokud existuje) + ikona + přeložený název kategorie
                        Row(
                          children: [
                            if (task.referenceNumber != null &&
                                task.referenceNumber!.trim().isNotEmpty) ...[
                              Text(
                                '#${task.referenceNumber!.trim()}',
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm),
                            ],
                            Icon(
                              typeIcon,
                              size: 16,
                              color: context.colors.onSurfaceVariant,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                taskTypeLabelKey(task.taskType).tr(),
                                style: context.textTheme.labelLarge?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs),
                        // 2. řádek – hlavní nadpis (externí: custom_title modře; apartmán: title/apartmentName)
                        Builder(
                          builder: (context) {
                            final isExternal = (task.apartmentId.trim().isEmpty);
                            final displayTitle = isExternal
                                ? (task.customTitle?.trim().isNotEmpty == true
                                      ? task.customTitle!
                                      : task.title.trim().isNotEmpty
                                      ? task.title
                                      : 'admin.task_no_title'.tr())
                                : (task.title.trim().isNotEmpty
                                      ? task.title
                                      : (task.apartmentName?.trim().isNotEmpty ==
                                              true
                                          ? task.apartmentName!
                                          : 'admin.task_no_title'.tr()));
                            return Text(
                              displayTitle,
                              style: context.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isExternal
                                    ? context.customColors.info
                                    : context.colors.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        if (customTags.isNotEmpty) ...[
                          SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: customTags.map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: t.color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t.label,
                                  style: context.textTheme.labelSmall?.copyWith(
                                    color: TaskCustomTag.readableForegroundOn(
                                      t.color,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        SizedBox(height: AppSpacing.xs),
                        // 3. řádek – lokace: externí = custom_location; apartmán = apartmentName
                        Builder(
                          builder: (context) {
                            final isExternal = (task.apartmentId.trim().isEmpty);
                            if (isExternal &&
                                task.customLocation != null &&
                                task.customLocation!.trim().isNotEmpty) {
                              return Text(
                                task.customLocation!,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            if (!isExternal &&
                                task.apartmentName != null &&
                                task.apartmentName!.trim().isNotEmpty &&
                                task.title.trim().isNotEmpty) {
                              return Text(
                                task.apartmentName!,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        Text(
                          assigned,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // 4. řádek – pilulky (stav, datum)
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: TaskCard.statusColor(
                                  normalizeToSystemStatus(task.status),
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                TaskCard.statusLabel(
                                  normalizeToSystemStatus(task.status),
                                ),
                                style: context.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: TaskCard.statusColor(
                                    normalizeToSystemStatus(task.status),
                                  ),
                                ),
                              ),
                            ),
                            KanbanTaskTimePill(timeWindowText: timeWindowText),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  // Ikona koše vpravo – Apple Vibe. U dokončených úkolů místo koše zámek (nelze mazat).
                  if (isLocked)
                    Icon(Icons.lock, size: 16, color: context.colors.outline)
                  else
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: context.colors.error.withValues(alpha: 0.75),
                      ),
                      onPressed: () => onDelete(task),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
