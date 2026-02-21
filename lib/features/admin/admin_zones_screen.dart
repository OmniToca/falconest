import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/features/settings/zones_list_tab.dart';

/// Obrazovka správy oblastí (zón) – samostatná route /settings/zones.
/// Používá [ZonesListTab] bez tlačítka nahoře (FAB zobrazí přidání).
/// Pro embedded zobrazení v Nastavení jako záložku viz [ZonesListTab].
class AdminZonesScreen extends ConsumerWidget {
  const AdminZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('admin.zones_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: ZonesListTab(showAddButton: true),
      ),
    );
  }
}
