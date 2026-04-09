import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_repository.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/providers/finance_tab_provider.dart';

/// Prémiový modální dialog detailu peněženky zaměstnance.
///
/// PROČ: Sjednocení designu s oknem Nastavení (SettingsModal) – centrované okno
/// s rozostřeným pozadím, animacemi Fade+Scale a identickým vizuálem (bílé pozadí,
/// zaoblené rohy 24, stín). Nahrazuje plnoobrazovkovou routu AdminWalletDetailScreen.
class WalletDetailModal {
  WalletDetailModal._();

  /// Otevře detail peněženky jako modální dialog – identická struktura jako [SettingsModal].
  ///
  /// PROČ: showGeneralDialog umožňuje custom transitionBuilder (blur, animace),
  /// zatímco showDialog má omezené možnosti. Klient vyžaduje stejný vizuál jako Nastavení.
  static Future<void> show(
    BuildContext context, {
    required String walletId,
    required String workerName,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'admin.finance.wallet_detail_title'
          .tr(namedArgs: {'name': workerName}),
      // PROČ: modal barrier má být centrálně řízený theme tokenem kvůli
      // jednotnému overlay vzhledu napříč admin modaly.
      barrierColor: context.customColors.modalBarrier,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (_, animation, secondaryAnimation, child) {
        // PROČ: Sjednocení designu s oknem Nastavení pomocí BackdropFilter a animací.
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: _WalletDetailModalContent(
                walletId: walletId,
                workerName: workerName,
                parentContext: context,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Otevře dialog pro převzetí hotovosti (částečný nebo celý výběr).
  /// Používá se v detailu peněženky i na přehledové obrazovce financí.
  static void showReceiveCashDialog(
    BuildContext context,
    WidgetRef ref,
    EmployeeCashWalletRow row,
  ) {
    final formattedBalance = formatWalletAmount(context, ref, row.balance);
    showDialog<void>(
      context: context,
      builder: (ctx) => _ReceiveCashDialog(
        row: row,
        formattedBalance: formattedBalance,
        parentContext: context,
      ),
    );
  }

  /// Otevře dialog pro vklad základu (float).
  static void showIssueFloatDialog(
    BuildContext context,
    WidgetRef ref,
    EmployeeCashWalletRow row,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _IssueFloatDialog(
        row: row,
        ref: ref,
        parentContext: context,
      ),
    );
  }

  /// Otevře dialog s fotkou účtenky – [InteractiveViewer] proti RenderFlex Overflow.
  ///
  /// Sdíleno mezi Admin (detail peněženky) a Worker (moje peněženka).
  static void showReceiptDialog(BuildContext context, String? url) {
    if (url == null || url.trim().isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(ctx).size.width * 0.9,
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Stack(
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 64),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vnitřní obsah modalu – převzat z AdminWalletDetailScreen, struktura jako SettingsModal.
/// PROČ: ConsumerStatefulWidget – potřebujeme lokální stav _showHistory pro filtrování transakcí.
class _WalletDetailModalContent extends ConsumerStatefulWidget {
  const _WalletDetailModalContent({
    required this.walletId,
    required this.workerName,
    required this.parentContext,
  });

  final String walletId;
  final String workerName;
  /// Kontext od volající obrazovky – platný i po zavření modalu, použit pro otevření detailu úkolu.
  final BuildContext parentContext;

  @override
  ConsumerState<_WalletDetailModalContent> createState() =>
      _WalletDetailModalContentState();
}

class _WalletDetailModalContentState extends ConsumerState<_WalletDetailModalContent> {
  /// Lokální stav – zda zobrazit i starší transakce (historie před posledním odevzdáním).
  bool _showHistory = false;

  static DateTime? _parseCreatedAt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Rozdělí transakce na aktuální (od posledního handoveru) a historii.
  /// Handover = HANDED_TO_AGENCY (odevzdáno agentuře). Aktuální = včetně handoveru.
  static ({List<CashTransactionUIModel> current, List<CashTransactionUIModel> history})
      _splitByLastHandover(List<CashTransactionUIModel> transactions) {
    // Seřadíme od nejnovějších (stream může mít libovolné pořadí).
    final sorted = List<CashTransactionUIModel>.from(transactions)
      ..sort((a, b) {
        final at = _parseCreatedAt(a.createdAt) ?? DateTime(1970);
        final bt = _parseCreatedAt(b.createdAt) ?? DateTime(1970);
        return bt.compareTo(at);
      });
    final lastHandoverIdx = sorted.indexWhere(
      (t) => (t.transactionType ?? '') == 'HANDED_TO_AGENCY',
    );
    if (lastHandoverIdx < 0) {
      return (current: sorted, history: []);
    }
    final handoverAt = _parseCreatedAt(sorted[lastHandoverIdx].createdAt);
    if (handoverAt == null) return (current: sorted, history: []);
    final current = sorted.where((t) {
      final tAt = _parseCreatedAt(t.createdAt) ?? DateTime(1970);
      return !tAt.isBefore(handoverAt);
    }).toList();
    final history = sorted.where((t) {
      final tAt = _parseCreatedAt(t.createdAt) ?? DateTime(1970);
      return tAt.isBefore(handoverAt);
    }).toList();
    return (current: current, history: history);
  }

  /// Spočítá celkové dýško z aktuálních transakcí COLLECTED_FROM_GUEST (amount - expected_amount).
  ///
  /// DÝŠKO = amount - expected_amount, ale POUZE když expected_amount je explicitně nastavené.
  /// Pokud expected_amount je null (běžné transfery, staré záznamy), nelze určit dýško –
  /// celý amount by byl chybně považován za dýško. Proto v takovém případě nic nepřičítáme.
  static double _sumTips(List<CashTransactionUIModel> transactions) {
    double sum = 0;
    for (final t in transactions) {
      if ((t.transactionType ?? '') != 'COLLECTED_FROM_GUEST') continue;
      final amount = _toDouble(t.raw['amount']) ?? 0;
      final expected = t.expectedAmount;
      // Bez expected_amount nelze určit dýško – nepřičítáme celý amount (fix pro běžné transfery)
      if (expected == null) continue;
      if (amount > expected && (amount - expected).abs() > 0.001) {
        sum += amount - expected;
      }
    }
    return sum;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final walletFromList = ref.watch(employeeCashWalletsProvider).valueOrNull
        ?.where((w) => w.id == widget.walletId)
        .firstOrNull;
    final row = walletFromList;
    final hasDebt = (row?.balance ?? 0) > 0;
    final displayName = (row?.workerName ?? widget.workerName).trim().isNotEmpty
        ? (row?.workerName ?? widget.workerName)
        : 'common.placeholder_dash'.tr();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            decoration: BoxDecoration(
              // PROČ: povrch modalu musí respektovat light/dark téma.
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  // PROČ: stín navazujeme na modal barrier token, aby byl
                  // kontrast konzistentní mezi režimy.
                  color: context.customColors.modalBarrier.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, displayName),
                Flexible(
                  child: ref.watch(walletTransactionsProvider(widget.walletId)).when(
                        data: (transactions) => _buildBody(
                          context,
                          ref,
                          transactions,
                          row,
                          hasDebt,
                          displayName,
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                              child: Text(
                                'admin.finance.load_error'.tr(),
                                style: TextStyle(color: context.colors.error),
                                textAlign: TextAlign.center,
                              ),
                            ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<CashTransactionUIModel> transactions,
    EmployeeCashWalletRow? row,
    bool hasDebt,
    String displayName,
  ) {
    if (transactions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBalanceHeader(context, displayName, 0, 0),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: Text(
                'admin.finance.wallet_history_empty'.tr(),
                style: TextStyle(color: context.colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (row != null) _buildActionButtons(context, ref, row),
        ],
      );
    }
    final split = _splitByLastHandover(transactions);
    final current = split.current;
    final history = split.history;
    final tipsSum = _sumTips(current);
    final balance = row?.balance ?? 0;

    final displayList = _showHistory ? [...current, ...history] : current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBalanceHeader(context, displayName, balance, tipsSum),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: displayList.length + (history.isNotEmpty && !_showHistory ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == displayList.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextButton(
                    onPressed: () => setState(() => _showHistory = true),
                    child: Text('admin.finance.wallet_show_history'.tr()),
                  ),
                );
              }
              final t = displayList[index];
              final hasTaskId = t.taskId != null && t.taskId!.isNotEmpty;
              return _TransactionTile(
                transaction: t,
                formatAmount: (v) => formatWalletAmount(context, ref, v),
                formatDate: (d) => formatTransactionDateShort(context, d),
                onReceiptTap: () => WalletDetailModal.showReceiptDialog(
                  context,
                  t.receiptImageUrl,
                ),
                onTap: hasTaskId ? () => _onTransactionTap(context, ref, t) : null,
              );
            },
          ),
        ),
        if (row != null) _buildActionButtons(context, ref, row),
      ],
    );
  }

  /// Hlavička s celkovým zůstatkem a dýškem z aktuálních transakcí.
  Widget _buildBalanceHeader(
    BuildContext context,
    String displayName,
    double balance,
    double tipsSum,
  ) {
    final formattedBalance = formatWalletAmount(context, ref, balance);
    final hasDebt = balance > 0;
    String balanceText = formattedBalance;
    if (tipsSum > 0.001) {
      balanceText =
          '$formattedBalance (${'admin.finance.wallet_header_tips'.tr(namedArgs: {'tips': formatWalletAmount(context, ref, tipsSum)})})';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            balanceText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasDebt
                      ? context.colors.error
                      : context.customColors.success,
                ),
          ),
        ],
      ),
    );
  }

  /// Řádek tlačítek: Převzít hotovost (jen když je co převzít) a Vložit základ.
  Widget _buildActionButtons(BuildContext context, WidgetRef ref, EmployeeCashWalletRow row) {
    final hasBalance = row.balance > 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (hasBalance)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    onPressed: () => _showReceiveCashDialog(context, ref, row),
                    icon: const Icon(Icons.handshake, size: 20),
                    label: Text('admin.finance.receive_btn'.tr()),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => _showIssueFloatDialog(context, ref, row),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: Text('admin.finance.issue_float_btn'.tr()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Při tapnutí transakce: pokud má taskId, otevři detail úkolu v Admin kontextu.
  /// Nedoplatek (nevyřešený) neotevírá úkol – místo toho přepne na záložku Podklady pro fakturaci.
  void _onTransactionTap(BuildContext context, WidgetRef ref, CashTransactionUIModel t) {
    final amount = _toDouble(t.raw['amount']);
    final expected = t.expectedAmount;
    final isResolved = t.raw['is_shortfall_resolved'] == true;
    if (expected != null && amount != null && amount < expected && !isResolved) {
      Navigator.of(context).pop();
      final ctx = widget.parentContext;
      ref.read(financeRequestedSubTabProvider.notifier).state = financeSubTabIndexBilling;
      AdminTabScope.of(ctx)?.call(adminTabIndexFinance);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('admin.finance.shortfall_resolve_in_billing'.tr())),
        );
      }
      return;
    }

    final taskId = t.taskId;
    if (taskId == null || taskId.isEmpty) return;

    Navigator.of(context).pop();

    // Použij parentContext – platný i po zavření modalu (caller's context).
    final ctx = widget.parentContext;

    // 1. Hledání v Admin streamu (aktivní úkoly).
    final tasks = ref.read(adminTasksStreamProvider).valueOrNull ?? [];
    var taskRow = tasks.where((task) => task.id == taskId).firstOrNull;

    // 2. Fallback: úkol může být dokončený/archivovaný – fetch přímo z DB.
    if (taskRow == null) {
      final tenantId = ref.read(authNotifierProvider).tenantIdForData;
      if (tenantId != null && tenantId.isNotEmpty) {
        AdminTasksRepository.fetchTaskById(tenantId, taskId).then((res) async {
          if (!ctx.mounted) return;
          if (res == null) {
            final switchToTab = AdminTabScope.of(ctx);
            if (switchToTab != null) switchToTab(adminTabIndexTasks);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('admin.finance.task_not_found_switch'.tr())),
            );
            return;
          }
          final apartments = await ref.read(apartmentsFullListProvider.future);
          final team = await ref.read(teamFullListProvider.future);
          final apartmentById = {for (final a in apartments) a.id: a.name};
          final nameByProfileId = <String, String>{};
          for (final m in team) {
            final id = m.profileId ?? m.id;
            if (id.isNotEmpty) nameByProfileId[id] = m.name;
          }
          final fetched = TaskRow.fromSupabaseRow(
            res,
            apartmentById: apartmentById,
            nameByProfileId: nameByProfileId,
          );
          if (ctx.mounted) {
            AdminTasksScreen.showEditTaskDialog(ctx, ref, fetched);
          }
        });
        return;
      }
      // Nelze fetchnout – přepni na Úkoly a informuj uživatele.
      final switchToTab = AdminTabScope.of(ctx);
      if (switchToTab != null) {
        switchToTab(adminTabIndexTasks);
      }
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('admin.finance.task_not_found_switch'.tr())),
        );
      }
      return;
    }

    AdminTasksScreen.showEditTaskDialog(ctx, ref, taskRow);
  }

  /// Hlavička modalu – stejný layout jako SettingsModal: název vlevo, křížek vpravo.
  Widget _buildHeader(BuildContext context, String displayName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'admin.finance.wallet_detail_title'.tr(namedArgs: {'name': displayName}),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.cancel'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showReceiveCashDialog(
    BuildContext context,
    WidgetRef ref,
    EmployeeCashWalletRow row,
  ) {
    WalletDetailModal.showReceiveCashDialog(context, ref, row);
  }

  void _showIssueFloatDialog(
    BuildContext context,
    WidgetRef ref,
    EmployeeCashWalletRow row,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _IssueFloatDialog(
        row: row,
        ref: ref,
        parentContext: context,
      ),
    );
  }
}

/// Rezervace z aktuálního období peněženky (od posledního HANDED) pro volitelnou vazbu při převzetí.
List<({String id, String label})> _receiveCashReservationOptions(
  List<CashTransactionUIModel> transactions,
) {
  final split = _WalletDetailModalContentState._splitByLastHandover(transactions);
  final byId = <String, String>{};
  for (final t in split.current) {
    if ((t.transactionType ?? '') != 'COLLECTED_FROM_GUEST') continue;
    final rawAmt = t.raw['amount'];
    final amount = rawAmt is num
        ? rawAmt.toDouble()
        : double.tryParse(rawAmt?.toString() ?? '');
    if (amount == null || amount <= 0) continue;
    final rid = t.reservationId;
    if (rid == null || rid.isEmpty) continue;
    final parts = <String>[
      if (t.apartmentName != null && t.apartmentName!.isNotEmpty) t.apartmentName!,
      if (t.guestName != null && t.guestName!.isNotEmpty) t.guestName!,
    ];
    final label = parts.isEmpty
        ? (rid.length >= 8 ? rid.substring(0, 8) : rid)
        : parts.join(' · ');
    byId[rid] = label;
  }
  final out = byId.entries.map((e) => (id: e.key, label: e.value)).toList();
  out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return out;
}

/// Dialog pro převzetí hotovosti – částečný nebo celý výběr s validací a loading stavem.
class _ReceiveCashDialog extends ConsumerStatefulWidget {
  const _ReceiveCashDialog({
    required this.row,
    required this.formattedBalance,
    required this.parentContext,
  });

  final EmployeeCashWalletRow row;
  final String formattedBalance;
  final BuildContext parentContext;

  @override
  ConsumerState<_ReceiveCashDialog> createState() => _ReceiveCashDialogState();
}

class _ReceiveCashDialogState extends ConsumerState<_ReceiveCashDialog> {
  late final TextEditingController _amountController;
  String? _amountError;
  bool _isLoading = false;
  String? _reservationId;
  bool _userPickedReservation = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.row.balance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  static double? _parseAmount(String s) {
    final normalized = s.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0 || amount > widget.row.balance) {
      setState(() {
        _amountError = 'admin.finance.receive_amount_error_invalid'.tr();
      });
      return;
    }
    setState(() {
      _amountError = null;
      _isLoading = true;
    });

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final adminProfileId = ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null || tenantId.isEmpty || adminProfileId == null || adminProfileId.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('admin.finance.receive_error_missing'.tr())),
        );
      }
      return;
    }

    String? ridForSubmit = _reservationId;
    final txList = ref.read(walletTransactionsProvider(widget.row.id)).value;
    if (txList != null) {
      final opts = _receiveCashReservationOptions(txList);
      if (ridForSubmit != null && !opts.any((o) => o.id == ridForSubmit)) {
        ridForSubmit = null;
      }
    }
    final rid = ridForSubmit?.trim();
    try {
      await CashWalletRepository.instance.receiveCashFromWorker(
        walletId: widget.row.id,
        workerProfileId: widget.row.profileId,
        amountToClear: amount,
        adminProfileId: adminProfileId,
        tenantId: tenantId,
        reservationId: (rid != null && rid.isNotEmpty) ? rid : null,
      );
      ref.invalidate(employeeCashWalletsProvider);
      ref.invalidate(walletTransactionsProvider(widget.row.id));
      if (rid != null && rid.isNotEmpty) {
        ref.invalidate(reservationCashTransitProvider(rid));
      }
      if (!mounted) return;
      if (!widget.parentContext.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(
          content: Text('admin.finance.receive_success'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.parentContext.mounted) {
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            SnackBar(content: Text('admin.finance.receive_error'.tr())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(walletTransactionsProvider(widget.row.id));
    final options = txAsync.maybeWhen(
      data: _receiveCashReservationOptions,
      orElse: () => <({String id, String label})>[],
    );

    final reservationDropdownValue = _reservationId != null &&
            options.any((o) => o.id == _reservationId)
        ? _reservationId
        : null;

    if (!_userPickedReservation && options.length == 1) {
      final only = options.single.id;
      if (_reservationId != only) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _reservationId = only);
        });
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('admin.finance.receive_confirm_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'admin.finance.receive_confirm_message'.tr(
                namedArgs: {'balance': widget.formattedBalance},
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'admin.finance.receive_amount_label'.tr(),
                hintText: 'admin.finance.receive_amount_hint'.tr(
                  namedArgs: {'balance': widget.formattedBalance},
                ),
                errorText: _amountError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _amountError = null),
            ),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'admin.finance.receive_reservation_label'.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'admin.finance.receive_reservation_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                // Controlled selection; `initialValue` does not follow stream/async updates.
                // ignore: deprecated_member_use
                value: reservationDropdownValue,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('admin.finance.receive_reservation_none'.tr()),
                  ),
                  ...options.map(
                    (o) => DropdownMenuItem<String?>(
                      value: o.id,
                      child: Text(o.label),
                    ),
                  ),
                ],
                onChanged: _isLoading
                    ? null
                    : (v) => setState(() {
                          _userPickedReservation = true;
                          _reservationId = v;
                        }),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('admin.finance.receive_btn_confirm'.tr()),
        ),
      ],
    );
  }
}

/// Dialog pro vklad základu (float) – částka a volitelná poznámka.
class _IssueFloatDialog extends StatefulWidget {
  const _IssueFloatDialog({
    required this.row,
    required this.ref,
    required this.parentContext,
  });

  final EmployeeCashWalletRow row;
  final WidgetRef ref;
  final BuildContext parentContext;

  @override
  State<_IssueFloatDialog> createState() => _IssueFloatDialogState();
}

class _IssueFloatDialogState extends State<_IssueFloatDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _amountError;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static double? _parseAmount(String s) {
    final normalized = s.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = 'admin.finance.issue_float_amount_error'.tr();
      });
      return;
    }
    setState(() {
      _amountError = null;
      _isLoading = true;
    });

    final tenantId = widget.ref.read(authNotifierProvider).tenantIdForData;
    final adminProfileId = widget.ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null || tenantId.isEmpty || adminProfileId == null || adminProfileId.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('admin.finance.receive_error_missing'.tr())),
        );
      }
      return;
    }

    try {
      await CashWalletRepository.instance.issueFloatToWorker(
        tenantId: tenantId,
        profileId: widget.row.profileId,
        amount: amount,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        adminProfileId: adminProfileId,
      );
      widget.ref.invalidate(employeeCashWalletsProvider);
      widget.ref.invalidate(walletTransactionsProvider(widget.row.id));
      if (!mounted) return;
      if (!widget.parentContext.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(
          content: Text('admin.finance.issue_float_success'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.parentContext.mounted) {
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            SnackBar(content: Text('admin.finance.issue_float_error'.tr())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('admin.finance.issue_float_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'admin.finance.issue_float_amount_label'.tr(),
                hintText: 'admin.finance.issue_float_amount_hint'.tr(),
                errorText: _amountError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _amountError = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'admin.finance.issue_float_note_label'.tr(),
                hintText: 'admin.finance.issue_float_note_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('admin.finance.issue_float_confirm_btn'.tr()),
        ),
      ],
    );
  }
}

/// Jedna transakce v seznamu – bohatý výpis: [Název úkolu] - [Host], datum, finanční rozpad.
/// Při tapnutí (pokud má taskId) otevře detail úkolu; bez taskId je řádek neklikatelný.
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.formatAmount,
    required this.formatDate,
    required this.onReceiptTap,
    this.onTap,
  });

  final CashTransactionUIModel transaction;
  final String Function(double) formatAmount;
  final String Function(DateTime) formatDate;
  final VoidCallback onReceiptTap;
  /// null = transakce bez úkolu (např. „Odevzdáno agentuře“) – neklikatelný řádek.
  final VoidCallback? onTap;

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final type = transaction.transactionType ?? '';
    final amount = _toDouble(transaction.raw['amount']) ?? 0;
    final expectedAmount = transaction.expectedAmount;
    final note = transaction.note;
    final receiptUrl = transaction.receiptImageUrl;
    final createdAt = transaction.createdAt;

    /// Nedoplatek: klient zaplatil méně než očekávaná částka – vizuálně zvýrazníme řádek a důvod.
    final isShortfall = expectedAmount != null &&
        (amount - expectedAmount).abs() > 0.001 &&
        amount < expectedAmount;

    String dateStr = 'common.placeholder_dash'.tr();
    if (createdAt != null) {
      final dt = createdAt is DateTime
          ? createdAt
          : (createdAt is String ? DateTime.tryParse(createdAt) : null);
      if (dt != null) {
        dateStr = formatDate(dt.toLocal());
      }
    }

    Color amountColor;
    final isPositive = amount > 0;
    final formattedAmount = isPositive
        ? '+ ${formatAmount(amount)}'
        : '- ${formatAmount(amount.abs())}';

    switch (type) {
      case 'COLLECTED_FROM_GUEST':
        amountColor = context.customColors.success;
        break;
      case 'HANDED_TO_AGENCY':
        amountColor = context.colors.onSurfaceVariant;
        break;
      case 'COMPANY_EXPENSE':
        amountColor = context.colors.error;
        break;
      case 'FLOAT_ISSUED':
        amountColor = context.customColors.info;
        break;
      default:
        amountColor = context.colors.onSurface;
    }

    // title: [Název úkolu] - [Jméno hosta/klienta], fallback na typ transakce.
    // Pro transakce s client_id (např. externí výdaj): zobrazíme jméno klienta.
    String titleText;
    if (transaction.hasClientContext &&
        (transaction.clientName != null && transaction.clientName!.isNotEmpty)) {
      final clientPart = transaction.clientName!;
      final typePart = transaction.clientType != null && transaction.clientType!.isNotEmpty
          ? ' (${transaction.clientType})'
          : '';
      titleText = '$clientPart$typePart';
    } else if (type == 'COLLECTED_FROM_GUEST' &&
        (transaction.taskTitle != null || transaction.guestName != null)) {
      final taskPart =
          (transaction.taskTitle ?? transaction.apartmentName ?? '').trim();
      final guestPart = (transaction.guestName ?? '').trim();
      if (taskPart.isNotEmpty && guestPart.isNotEmpty) {
        titleText = '$taskPart - $guestPart';
      } else if (taskPart.isNotEmpty) {
        titleText = taskPart;
      } else if (guestPart.isNotEmpty) {
        titleText = guestPart;
      } else {
        titleText = 'admin.finance.transaction_collected'.tr();
      }
    } else {
      switch (type) {
        case 'COLLECTED_FROM_GUEST':
          titleText = 'admin.finance.transaction_collected'.tr();
          break;
        case 'HANDED_TO_AGENCY':
          titleText = 'admin.finance.transaction_handed'.tr();
          break;
        case 'COMPANY_EXPENSE':
          titleText = 'admin.finance.transaction_expense'.tr();
          break;
        case 'FLOAT_ISSUED':
          titleText = 'admin.finance.transaction_float_issued'.tr();
          break;
        default:
          titleText = type;
      }
    }

    // subtitle: datum + kontext klienta (pokud má) + finanční rozpad
    final subtitleParts = <Widget>[
      Text(
        dateStr,
        style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 12),
      ),
    ];
    if (transaction.hasClientContext) {
      final clientName = transaction.clientName ?? 'common.placeholder_dash'.tr();
      final clientType = transaction.clientType;
      subtitleParts.add(const SizedBox(height: 2));
      subtitleParts.add(
        Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: context.colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '${'admin.finance.transaction_client_label'.tr()}: $clientName',
              style: TextStyle(color: context.colors.onSurface, fontSize: 12),
            ),
            if (clientType != null && clientType.isNotEmpty) ...[
              const SizedBox(width: 6),
              _ClientTypeBadge(clientType: clientType),
            ],
          ],
        ),
      );
    }

    // Finanční rozpad (Očekáváno: X, Dýško: Y) pokud existuje expected_amount
    String? breakdownText;
    if (type == 'COLLECTED_FROM_GUEST' &&
        expectedAmount != null &&
        (amount - expectedAmount).abs() > 0.001) {
      final diff = amount - expectedAmount;
      if (diff > 0) {
        breakdownText =
            '${'admin.finance.transaction_expected'.tr()}: ${formatAmount(expectedAmount)}, ${'admin.finance.transaction_tip'.tr()}: ${formatAmount(diff)}';
      } else {
        breakdownText =
            '${'admin.finance.transaction_expected'.tr()}: ${formatAmount(expectedAmount)}, ${'admin.finance.transaction_underpayment'.tr()}: ${formatAmount(-diff)}';
      }
    } else if (expectedAmount != null && type == 'COLLECTED_FROM_GUEST') {
      breakdownText =
          '${'admin.finance.transaction_expected'.tr()}: ${formatAmount(expectedAmount)}';
    } else if (note != null && note.isNotEmpty) {
      breakdownText = note;
    }

    // Finanční rozpad a poznámka: u nedoplatku červeně + tučně, poznámku vždy s varovnou ikonou.
    if (breakdownText != null && breakdownText.isNotEmpty) {
      subtitleParts.add(const SizedBox(height: 2));
      final isBreakdownSameAsNote =
          note != null && note.isNotEmpty && breakdownText == note;
      if (isBreakdownSameAsNote) {
        subtitleParts.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: context.colors.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  breakdownText,
                  style: TextStyle(
                    color: context.colors.error,
                    fontSize: 12,
                    fontWeight:
                        isShortfall ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        subtitleParts.add(
          Text(
            breakdownText,
            style: TextStyle(
              color: isShortfall ? context.colors.error : context.colors.onSurface,
              fontSize: 12,
              fontWeight: isShortfall ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }
      if (note != null && note.isNotEmpty && breakdownText != note) {
        subtitleParts.add(const SizedBox(height: 2));
        subtitleParts.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: context.colors.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  note,
                  style: TextStyle(
                    color: context.colors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    Widget trailing = Text(
      formattedAmount,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: amountColor,
        fontSize: 15,
      ),
    );
    if (receiptUrl != null && receiptUrl.isNotEmpty) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formattedAmount,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: amountColor,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onReceiptTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                receiptUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.receipt_long, size: 28),
              ),
            ),
          ),
        ],
      );
    }

    return ListTile(
      // PROČ: nedoplatek zvýrazníme sémantickým error containerem.
      tileColor: isShortfall ? context.colors.errorContainer : null,
      title: Text(titleText),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: subtitleParts,
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Malý badge pro zobrazení typu klienta (Majitel / Agentura / Externí).
class _ClientTypeBadge extends StatelessWidget {
  const _ClientTypeBadge({required this.clientType});

  final String clientType;

  String _label() {
    switch (clientType.toLowerCase()) {
      case 'owner':
        return 'clients.type_owner'.tr();
      case 'agency':
        return 'clients.type_agency'.tr();
      case 'external':
        return 'clients.type_external'.tr();
      default:
        return clientType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: context.customColors.infoSubtle,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.customColors.info.withValues(alpha: 0.3)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: context.customColors.info,
        ),
      ),
    );
  }
}
