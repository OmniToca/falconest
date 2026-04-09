import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/providers/sync_status_provider.dart';
import 'package:falconest/core/widgets/app_empty_state.dart';
import 'package:falconest/features/worker/providers/pending_mutations_provider.dart';
import 'package:falconest/features/worker/services/mutation_queue_item_label_resolver.dart';

const _primaryBlue = Color(0xFF1565C0);

/// Obrazovka seznamu položek lokální offline fronty (pending_mutations v Drift).
///
/// PROČ: Worker má přehled, co ještě nebylo odesláno na Supabase, a může ručně spustit
/// [processQueue] bez hledání v nastavení – doplňuje žlutý banner na dashboardu.
class WorkerMutationQueueScreen extends ConsumerStatefulWidget {
  const WorkerMutationQueueScreen({super.key});

  @override
  ConsumerState<WorkerMutationQueueScreen> createState() =>
      _WorkerMutationQueueScreenState();
}

class _WorkerMutationQueueScreenState extends ConsumerState<WorkerMutationQueueScreen> {
  bool _processRunning = false;

  /// Ruční odeslání fronty – stejná logika jako po návratu sítě; nezasahujeme do vnitřku služby.
  Future<void> _triggerProcessQueue() async {
    if (_processRunning) return;
    setState(() => _processRunning = true);
    try {
      await ref.read(mutationQueueServiceProvider).processQueue();
      ref.invalidate(syncStatusProvider);
      ref.invalidate(pendingMutationsProvider);
    } finally {
      if (mounted) setState(() => _processRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(pendingMutationsProvider);
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('worker.mutation_queue_title'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'worker.mutation_queue_sync_tooltip'.tr(),
            onPressed: _processRunning ? null : _triggerProcessQueue,
            icon: _processRunning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _processRunning ? null : _triggerProcessQueue,
        icon: _processRunning
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cloud_upload),
        label: Text('worker.mutation_queue_fab_sync'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'worker.mutation_queue_load_error'.tr(
                namedArgs: {'message': '$e'},
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AppEmptyState(
                  icon: Icons.cloud_done_outlined,
                  title: 'worker.mutation_queue_empty_title'.tr(),
                  subtitle: 'worker.mutation_queue_empty_subtitle'.tr(),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _triggerProcessQueue,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final m = items[index];
                final sub = MutationQueueItemLabelResolver.secondaryLine(m);
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.queue_outlined, color: Colors.blue.shade700, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                MutationQueueItemLabelResolver.primaryLine(m),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (sub != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            sub,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'worker.mutation_queue_created_at'.tr(
                            namedArgs: {'datetime': dateFmt.format(m.createdAt.toLocal())},
                          ),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
