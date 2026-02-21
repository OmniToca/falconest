import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Klientský panel pro majitele bytů (role property_owner).
///
/// Placeholder pro budoucí funkce – majitel uvidí své byty, úkoly k nim
/// přiřazené a další informace. Připraveno pro Fázi 2+.
class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'owner.dashboard_title'.tr(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
