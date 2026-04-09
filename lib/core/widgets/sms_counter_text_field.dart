import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/utils/sms_counter_utils.dart';

/// Podpis pod textovým polem: znaky, počet SMS segmentů, kódování a varování při Unicode.
///
/// PROČ: Čistě prezentační widget – bere [text] zvenku; při psaní má rodič předávat
/// aktuální řetězec (nebo použít [SmsTextField], který to dělá přes [setState]).
class SmsCounterInfo extends StatelessWidget {
  /// [text] – aktuální obsah pole (pro výpočet segmentů v reálném čase).
  const SmsCounterInfo({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.only(top: 8),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final result = SmsCounterUtils.analyze(text);
    final scheme = Theme.of(context).colorScheme;
    final encodingLabel = result.isUnicode
        ? 'communication.sms_counter_encoding_unicode'.tr()
        : 'communication.sms_counter_encoding_gsm'.tr();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                'communication.sms_counter_characters'.tr(namedArgs: {'count': '${result.characterCount}'}),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              Text('·', style: TextStyle(color: scheme.onSurfaceVariant)),
              Text(
                'communication.sms_counter_segments'.tr(namedArgs: {'count': '${result.smsSegments}'}),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text('·', style: TextStyle(color: scheme.onSurfaceVariant)),
              Text(
                encodingLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          if (result.isUnicode) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'communication.sms_counter_unicode_warning'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// [TextField] s lokálním [setState] a [SmsCounterInfo] pod polem.
///
/// PROČ: Posluchač na [controller] překreslí jen tento subtree – žádný Riverpod
/// při každém úhozu.
class SmsTextField extends StatefulWidget {
  const SmsTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.maxLines,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.style,
    this.onChanged,
    this.showCounter = true,
    this.counterPadding = const EdgeInsets.only(top: 8),
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;

  /// Zda zobrazit [SmsCounterInfo] pod polem.
  final bool showCounter;
  final EdgeInsetsGeometry counterPadding;

  @override
  State<SmsTextField> createState() => _SmsTextFieldState();
}

class _SmsTextFieldState extends State<SmsTextField> {
  void _onTextChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SmsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          decoration: widget.decoration,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          style: widget.style,
          onChanged: widget.onChanged,
        ),
        if (widget.showCounter)
          SmsCounterInfo(
            text: widget.controller.text,
            padding: widget.counterPadding,
          ),
      ],
    );
  }
}
