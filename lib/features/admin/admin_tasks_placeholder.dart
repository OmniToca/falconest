import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Placeholder obrazovka pro sekci Úkoly.
///
/// Úkoly jsou na konci hierarchie – po Personálu a Bytech.
/// Bude doplněna v další iteraci.
class AdminTasksPlaceholder extends StatelessWidget {
  const AdminTasksPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.task_alt,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'admin.tasks_placeholder'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
