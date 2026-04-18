import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index záložky „Podklady pro fakturaci“ v rámci obrazovky Finance (TabBarView).
/// Tab 0 = Peněženky, 1 = Vyúčtování (settlements), 2 = Podklady pro fakturaci, 3 = Žádosti majitelů (hotovost).
const int financeSubTabIndexBilling = 2;

/// Žádosti majitelů o výplatu průtokové hotovosti (`AdminOwnerCashRequestsScreen`).
const int financeSubTabIndexOwnerCashRequests = 3;

/// Po nastavení na hodnotu indexu (např. [financeSubTabIndexBilling]) obrazovka Finance
/// po příštím sestavení přepne vnitřní TabController na tuto záložku a hodnotu vynuluje.
///
/// PROČ: Nástěnka a modal peněženky potřebují navigovat přímo na „Podklady pro fakturaci“,
/// ne jen na obecnou záložku Finance (kde by byl výchozí tab Peněženky).
final financeRequestedSubTabProvider = StateProvider<int?>((ref) => null);
