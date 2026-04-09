import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/omnibox_search_provider.dart';

/// Spotlight-like modální vyhledávání napříč Admin daty (klienti, apartmány, úkoly).
///
/// PROČ: Uživatel v operativním provozu potřebuje přeskočit mezi entitami bez ručního
/// přepínání záložek. Omnibox centralizuje full-text vstup a vrací přímo cílový záznam.
class OmniboxDialog extends ConsumerStatefulWidget {
  const OmniboxDialog({super.key});

  @override
  ConsumerState<OmniboxDialog> createState() => _OmniboxDialogState();
}

class _OmniboxDialogState extends ConsumerState<OmniboxDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(omniboxSearchQueryProvider.notifier).state = _searchController.text;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(omniboxSearchQueryProvider);
    final resultsAsync = ref.watch(omniboxSearchResultsProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 620),
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'admin.omnibox_title'.tr(),
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'admin.omnibox_placeholder'.tr(),
                        suffixIcon: IconButton(
                          tooltip: 'common.close'.tr(),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _buildResultsContent(
                  context: context,
                  query: query,
                  resultsAsync: resultsAsync,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsContent({
    required BuildContext context,
    required String query,
    required AsyncValue<List<OmniboxSearchResult>> resultsAsync,
  }) {
    final normalized = query.trim();
    if (normalized.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'admin.omnibox_min_chars'.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'common.generic_error_user_friendly'.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'admin.omnibox_no_results'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = results[index];
            return _OmniboxResultTile(
              item: item,
              onTap: () => Navigator.of(context).pop(item),
            );
          },
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemCount: results.length,
        );
      },
    );
  }
}

/// Jeden výsledek v seznamu omniboxu.
///
/// PROČ: Kompaktní tile s ikonou typu entity a sekundárním popisem pomáhá rychle
/// rozlišit, zda jde o Klienta, Byt nebo Úkol při smíšeném full-text výsledku.
class _OmniboxResultTile extends StatelessWidget {
  const _OmniboxResultTile({
    required this.item,
    required this.onTap,
  });

  final OmniboxSearchResult item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      OmniboxEntityType.client => Icons.person_outline_rounded,
      OmniboxEntityType.apartment => Icons.apartment_rounded,
      OmniboxEntityType.task => Icons.task_alt_rounded,
    };
    final chipLabel = switch (item.type) {
      OmniboxEntityType.client => 'admin.omnibox_type_client'.tr(),
      OmniboxEntityType.apartment => 'admin.omnibox_type_apartment'.tr(),
      OmniboxEntityType.task => 'admin.omnibox_type_task'.tr(),
    };

    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: context.colors.primaryContainer,
        foregroundColor: context.colors.onPrimaryContainer,
        child: Icon(icon, size: 18),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpacing.xs),
          if (item.subtitle != null && item.subtitle!.trim().isNotEmpty)
            Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              chipLabel,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colors.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: context.colors.outline),
      onTap: onTap,
    );
  }
}
