import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';

/// Varovný pruh režimu náhledu Owner portálu – dispečer prohlíží data jako majitel.
///
/// PROČ: Stejný vizuální jazyk jako HQ [_ImpersonationBanner] v [AdminLayout] –
/// pevně nahoře, výrazná barva [CustomColors.warning], tlačítko pro návrat do CRM.
class OwnerViewImpersonationBanner extends StatelessWidget {
  const OwnerViewImpersonationBanner({
    super.key,
    required this.displayName,
    required this.onStop,
  });

  final String displayName;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final template = 'admin.owner_view_banner'.tr();
    const placeholder = '{name}';
    final idx = template.indexOf(placeholder);
    final cc = context.customColors;
    final bannerFg = cc.onWarning;
    final bodyStyle = context.textTheme.titleSmall?.copyWith(
      color: bannerFg,
      fontWeight: FontWeight.w600,
    );

    Widget textWidget;
    if (idx >= 0) {
      final before = template.substring(0, idx);
      final after = template.substring(idx + placeholder.length);
      textWidget = Text.rich(
        TextSpan(
          style: bodyStyle,
          children: [
            TextSpan(text: before),
            TextSpan(
              text: displayName.isNotEmpty ? displayName : '…',
              style: bodyStyle?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: after),
          ],
        ),
      );
    } else {
      textWidget = Text(
        displayName.isNotEmpty
            ? template.replaceAll(placeholder, displayName)
            : template,
        style: bodyStyle,
      );
    }

    return Material(
      color: cc.warning,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Expanded(child: textWidget),
              const SizedBox(width: AppSpacing.md),
              TextButton(
                onPressed: onStop,
                style: TextButton.styleFrom(
                  foregroundColor: bannerFg,
                  side: BorderSide(color: bannerFg),
                ),
                child: Text('admin.owner_view_stop'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
