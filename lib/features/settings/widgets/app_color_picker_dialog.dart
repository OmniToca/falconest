import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Jednoduchý výběr barvy (HSV posuvníky) bez externí závislosti.
///
/// PROČ: Balíček `flutter_colorpicker` v projektu není; Material neposkytuje hotový picker.
/// Tento dialog stačí pro B2B úpravu brandových barev a funguje na mobilu i webu.
Future<Color?> showAppColorPickerDialog({
  required BuildContext context,
  required Color initialColor,
}) {
  return showDialog<Color>(
    context: context,
    builder: (ctx) => _AppColorPickerDialog(initialColor: initialColor),
  );
}

class _AppColorPickerDialog extends StatefulWidget {
  const _AppColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_AppColorPickerDialog> createState() => _AppColorPickerDialogState();
}

class _AppColorPickerDialogState extends State<_AppColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _hsv.toColor();
    return AlertDialog(
      title: Text('settings.colors_picker_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'settings.colors_picker_preview'.tr(),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: preview,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'settings.colors_picker_hue'.tr(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Slider(
              value: _hsv.hue.clamp(0.0, 360.0),
              min: 0,
              max: 360,
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            Text(
              'settings.colors_picker_saturation'.tr(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Slider(
              value: _hsv.saturation.clamp(0.0, 1.0),
              min: 0,
              max: 1,
              onChanged: (v) =>
                  setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            Text(
              'settings.colors_picker_value'.tr(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Slider(
              value: _hsv.value.clamp(0.0, 1.0),
              min: 0,
              max: 1,
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(preview),
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}
