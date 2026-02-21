import 'package:flutter/material.dart';

/// Široký bílý panel pro hlavní editační dialogy (Apartmány, Rezervace, Personál, Úkoly).
/// Sjednocuje vzhled s hlavním Nastavením – velkorysý padding, bílé pozadí, zaoblené rohy.
/// Není to klasický malý AlertDialog; obsah je scrollovatelný a panel má nastavitelnou max šířku (default 800).
class ModernAdminPanel extends StatelessWidget {
  const ModernAdminPanel({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 800,
  });

  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: maxWidth,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(child: content),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
