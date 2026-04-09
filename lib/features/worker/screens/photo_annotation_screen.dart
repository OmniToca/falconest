import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Výpočet cílového obdélníku pro `BoxFit.contain` — sdílený mezi gesty a malířem.
Rect _imageContainRect(Size box, int iw, int ih) {
  final s = math.min(box.width / iw, box.height / ih);
  final w = iw * s;
  final h = ih * s;
  final left = (box.width - w) / 2;
  final top = (box.height - h) / 2;
  return Rect.fromLTWH(left, top, w, h);
}

/// Celá obrazovka: nakreslení červených čar přes fotku před odesláním do úložiště.
///
/// PROČ: Pracovník v terénu označí konkrétní místo závady; výstup je jeden PNG spojující
/// originál a vektorové tahy (export přes [PictureRecorder] ve stejném rozlišení jako snímek).
class PhotoAnnotationScreen extends StatefulWidget {
  const PhotoAnnotationScreen({super.key, required this.imageFile});

  final File imageFile;

  @override
  State<PhotoAnnotationScreen> createState() => _PhotoAnnotationScreenState();
}

class _PhotoAnnotationScreenState extends State<PhotoAnnotationScreen> {
  ui.Image? _image;
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _image = frame.image);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Offset? _localToImage(Offset local, Size box) {
    final img = _image;
    if (img == null) return null;
    final dst = _imageContainRect(box, img.width, img.height);
    if (!dst.contains(local)) return null;
    final rx = (local.dx - dst.left) / dst.width;
    final ry = (local.dy - dst.top) / dst.height;
    return Offset(rx * img.width, ry * img.height);
  }

  Future<File?> _saveAnnotated() async {
    final img = _image;
    if (img == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(img, Offset.zero, Paint());

    final scale = img.width / 400;
    final strokeW = math.max(2.0, 3.5 * scale);
    final strokePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in _strokes) {
      if (stroke.length >= 2) {
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (var i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, strokePaint);
      } else if (stroke.length == 1) {
        final fillPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stroke.first, strokeW * 1.2, fillPaint);
      }
    }

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(img.width, img.height);
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final outPath = p.join(dir.path, 'annotated_${DateTime.now().millisecondsSinceEpoch}.png');
    final out = File(outPath);
    await out.writeAsBytes(bytes);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text('worker.photo_annotation_title'.tr())),
        body: Center(child: Text('common.generic_error_user_friendly'.tr())),
      );
    }

    if (_image == null) {
      return Scaffold(
        appBar: AppBar(title: Text('worker.photo_annotation_title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('worker.photo_annotation_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop<File?>(null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop<File?>(widget.imageFile),
            child: Text('worker.photo_annotation_skip'.tr()),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: () async {
                final f = await _saveAnnotated();
                if (!context.mounted) return;
                if (f != null) {
                  Navigator.of(context).pop<File?>(f);
                }
              },
              child: Text('worker.photo_annotation_save'.tr()),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'worker.photo_annotation_hint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) {
                    final p0 = _localToImage(d.localPosition, size);
                    if (p0 != null) {
                      setState(() {
                        _currentStroke = [p0];
                      });
                    }
                  },
                  onPanUpdate: (d) {
                    final p1 = _localToImage(d.localPosition, size);
                    if (p1 != null && _currentStroke != null) {
                      setState(() => _currentStroke!.add(p1));
                    }
                  },
                  onPanEnd: (_) {
                    final cur = _currentStroke;
                    if (cur != null && cur.isNotEmpty) {
                      setState(() {
                        _strokes.add(List<Offset>.from(cur));
                        _currentStroke = null;
                      });
                    }
                  },
                  child: CustomPaint(
                    size: size,
                    painter: _AnnotationOverlayPainter(
                      image: _image!,
                      strokes: _strokes,
                      currentStroke: _currentStroke,
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

class _AnnotationOverlayPainter extends CustomPainter {
  _AnnotationOverlayPainter({
    required this.image,
    required this.strokes,
    required this.currentStroke,
  });

  final ui.Image image;
  final List<List<Offset>> strokes;
  final List<Offset>? currentStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = _imageContainRect(size, image.width, image.height);
    canvas.drawImageRect(image, src, dst, Paint());

    final scale = dst.width / image.width;
    final strokeW = math.max(2.0, 3.5 * scale);
    final paintLine = Paint()
      ..color = Colors.red
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawStroke(List<Offset> pts) {
      if (pts.length < 2) return;
      final path = Path();
      final first = Offset(dst.left + pts.first.dx * scale, dst.top + pts.first.dy * scale);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < pts.length; i++) {
        final o = Offset(dst.left + pts[i].dx * scale, dst.top + pts[i].dy * scale);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paintLine);
    }

    for (final s in strokes) {
      if (s.length >= 2) {
        drawStroke(s);
      } else if (s.length == 1) {
        final c = Offset(dst.left + s.first.dx * scale, dst.top + s.first.dy * scale);
        canvas.drawCircle(
          c,
          strokeW * 1.2,
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill,
        );
      }
    }
    if (currentStroke != null) {
      if (currentStroke!.length >= 2) {
        drawStroke(currentStroke!);
      } else if (currentStroke!.length == 1) {
        final c = Offset(
          dst.left + currentStroke!.first.dx * scale,
          dst.top + currentStroke!.first.dy * scale,
        );
        canvas.drawCircle(
          c,
          strokeW * 1.2,
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationOverlayPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}
