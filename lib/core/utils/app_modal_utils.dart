import 'dart:ui';

import 'package:flutter/material.dart';

/// Sdílená utilita pro prémiové centrované modály (blur, animace, zaoblené rohy).
///
/// PROČ: Nastavení, Fakturace, Detail agentury a další modály opakovaně používají
/// showGeneralDialog + BackdropFilter + FadeTransition + ScaleTransition. Tato utilita
/// eliminuje duplicitu a sjednocuje vizuál napříč aplikací.
///
/// [maxHeightPx] – volitelná pevná maximální výška v px. Pokud null, použije se
/// [maxHeightFraction] × výška obrazovky.
Future<T?> showAppModal<T>({
  required BuildContext context,
  required String barrierLabel,
  required Widget child,
  double maxWidth = 500,
  double maxHeightFraction = 0.85,
  double? maxHeightPx,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, __, ___) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeightPx ?? MediaQuery.of(ctx).size.height * maxHeightFraction,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
