import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';

/// Jednotný prázdný stav seznamu nebo sekce (ikona, titulek, volitelný podtitulek a akce).
///
/// PROČ: Sjednocení vizuálu „nic k zobrazení“ napříč moduly; texty předává volající
/// (lokalizované řetězce z JSON), widget zůstává v core bez závislosti na features.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  /// Ikona stavu (např. [Icons.inbox_outlined]).
  final IconData icon;

  /// Hlavní zpráva (např. přeložený klíč z i18n).
  final String title;

  /// Doplňující text pod titulkem.
  final String? subtitle;

  /// Volitelné tlačítko nebo řádek akcí (např. [FilledButton]).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tt = context.textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppSpacing.xxl,
            color: colors.primary,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
