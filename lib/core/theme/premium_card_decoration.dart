import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';

/// Společná dekorace „prémiové“ karty (nástěnka, CRM dlaždice).
///
/// PROČ centralizace: Stejný vizuál (surface + měkký stín z tématu) bez duplikace
/// v admin_dashboard a dalších obrazovkách; žádné hardcoded bílé podklady.
BoxDecoration premiumCardDecoration(BuildContext context) => BoxDecoration(
  color: context.colors.surface,
  borderRadius: BorderRadius.circular(AppSpacing.md),
  boxShadow: [
    BoxShadow(
      color: context.colors.shadow.withValues(alpha: 0.12),
      blurRadius: AppSpacing.md,
      offset: Offset(0, AppSpacing.sm),
    ),
  ],
);

/// Obal karty s [premiumCardDecoration] – ClipRRect + Material + Ink (+ volitelný InkWell).
///
/// PROČ: Sjednocení Finance / Vyúčtování s nástěnkou (Kanban); bez duplikace AppCard.
/// [onTap] == null znamená jen dekoraci bez ripple (např. souhrnná karta bez kliknutí na celý obdélník).
Widget premiumCardShell(
  BuildContext context, {
  VoidCallback? onTap,
  required Widget child,
}) {
  final radius = BorderRadius.circular(AppSpacing.md);
  final deco = premiumCardDecoration(context);
  return ClipRRect(
    borderRadius: radius,
    child: Material(
      color: Colors.transparent,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Ink(decoration: deco, child: child),
            )
          : Ink(decoration: deco, child: child),
    ),
  );
}
