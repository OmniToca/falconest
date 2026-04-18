import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';

/// Společné konstanty a pomůcky pro vizuální sjednocení Klientského centra (majitel).
///
/// PROČ: Přechod z „admin nástroje“ na produkt – konzistentní rámečky, měkké plochy a ikony
/// bez duplikace magic numbers v každé obrazovce.

/// Maximální šířka textového sloupce na širokém okně – větší než ~1000 px lépe využije desktop,
/// stále omezuje délku řádků oproti full-bleed.
const double kOwnerPortalContentMaxWidth = 1200;

/// Stejný práh jako postranní panel v [OwnerLayout] – pod ním drawer, nad ním sidebar.
const double kOwnerPortalWideLayoutMinWidth = 800;

const double kOwnerPortalCardRadius = 16;

/// Zaoblení karet Kanbanu (rezervace / úkoly majitele) – výraznější „karta nad plochou“.
const double kOwnerPortalKanbanCardRadius = 18;

/// Měkký stín ve stylu iOS / Apple 2026 – velký blur, velmi nízká opacity (ne těžký Material elevation).
List<BoxShadow> ownerPortalKanbanCardShadows() => [
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.05),
        blurRadius: 24,
        offset: const Offset(0, 10),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.035),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];

/// Bílá / [ColorScheme.surface] karta s jemným stínem a téměř neviditelným obrysem.
BoxDecoration ownerPortalKanbanCardDecoration(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: cs.surface,
    borderRadius: BorderRadius.circular(kOwnerPortalKanbanCardRadius),
    boxShadow: ownerPortalKanbanCardShadows(),
    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.08)),
  );
}

/// Omezí šířku obsahu na velkých monitorech – příjemnější čtení než full-bleed řádky.
///
/// PROČ: [Center] vytvářel dojem „plavoucího“ bloku uprostřed hlavní plochy, odděleného od
/// levého menu. [Alignment.topLeft] + vodorovný padding naváže obsah vizuálně na sidebar;
/// na úzkém okně (< [kOwnerPortalWideLayoutMinWidth]) zůstává jen standardní odsazení [AppSpacing.md].
Widget ownerPortalConstrainBody({required Widget child}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= kOwnerPortalWideLayoutMinWidth;
      // Úzké okno: symetrický standard; široké: víc zleva kvůli návaznosti na sidebar.
      final pad = wide
          ? const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.md, 0)
          : const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      return Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: pad,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kOwnerPortalContentMaxWidth,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Jemná karta: světlá plocha z tématu + tenký okraj (místo těžkých stínů).
BoxDecoration ownerPortalSectionDecoration(BuildContext context) {
  final c = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: c.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(kOwnerPortalCardRadius),
    border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
  );
}

/// Ikona pro blok úkolu v plánovacím kalendáři podle typu (koště / klíč / údržba).
IconData ownerPortalCalendarTaskIcon(String taskType) {
  final t = taskType.toLowerCase().trim().replaceAll('-', '_');
  if (t.contains('clean')) return Icons.cleaning_services_rounded;
  if (t.contains('transfer') || t.contains('check_in') || t.contains('check_out')) {
    return Icons.vpn_key_rounded;
  }
  if (t.contains('maintenance') || t.contains('material')) return Icons.handyman_outlined;
  if (t.contains('issue')) return Icons.report_problem_outlined;
  return Icons.task_alt_rounded;
}

/// Ztlumené pozadí karty úkolu: barva kategorie se míchá se surface – méně „agresivní“ než plná saturace.
Color ownerPortalMutedTaskFill(BuildContext context, Color categoryColor) {
  final base = context.colors.surface;
  return Color.alphaBlend(categoryColor.withValues(alpha: 0.14), base);
}
