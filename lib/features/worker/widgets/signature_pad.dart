import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';

/// Podpisové plátno pro získání ručního podpisu hosta na mobilu.
///
/// PROČ: V terénu potřebujeme rychlý důkaz převzetí služby bez externí knihovny.
/// Kombinace `GestureDetector` + `CustomPainter` umožní jednoduchý, spolehlivý a
/// auditovatelný podpis, který následně uložíme jako PNG do Storage.
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.onConfirm,
  });

  final ValueChanged<Uint8List> onConfirm;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = <Offset?>[];
  final GlobalKey _paintKey = GlobalKey();

  bool get _hasSignature => _points.any((p) => p != null);

  void _addPoint(Offset localPosition) {
    setState(() => _points.add(localPosition));
  }

  void _endStroke() {
    if (_points.isNotEmpty && _points.last != null) {
      setState(() => _points.add(null));
    }
  }

  Future<void> _confirm() async {
    if (!_hasSignature) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('worker.signature_empty_warning'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final boundary = _paintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    widget.onConfirm(byteData.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _addPoint(d.localPosition),
            onPanUpdate: (d) => _addPoint(d.localPosition),
            onPanEnd: (_) => _endStroke(),
            child: RepaintBoundary(
              key: _paintKey,
              // PROČ: Export PNG bere jen obsah boundary — bez vyplněného pozadí by byl PNG
              // průhledný a tahy v barvě onSurface by v tmavém tématu mohly být neviditelné / „bílé“.
              child: CustomPaint(
                painter: _SignaturePainter(points: _points),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(_points.clear),
                icon: const Icon(Icons.delete_outline),
                label: Text('worker.signature_clear'.tr()),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check_rounded),
                label: Text('worker.signature_confirm'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.points});

  final List<Offset?> points;

  /// Jednotný vzhled podpisu pro zobrazení i export: černá fixa na bílém papíru (nezávislé na tématu).
  static const Color _paper = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF000000);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);

    final paint = Paint()
      ..color = _ink
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
