import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_theme.dart';

/// Univerzální karta – sjednocený vzhled panelů napříč administrací.
///
/// Moderní SaaS design: větší zakulacení (16px), velmi jemný rozptýlený stín.
/// Barva z [backgroundColor], jinak AppThemeColors.cardColor (bílá). Používá se pro KPI karty, seznamy, formuláře.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  /// Volitelná barva pozadí – např. pastelová barva podle typu úkolu. Pokud null, použije se cardColor z tématu.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>();
    final cardColor = backgroundColor ?? (colors?.cardColor ?? Colors.white);

    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    final decorated = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: decorated,
        ),
      );
    }
    return decorated;
  }
}
