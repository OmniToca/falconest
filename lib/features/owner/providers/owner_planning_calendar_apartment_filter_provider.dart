import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stav výběru bytu v plánovacím kalendáři majitele.
///
/// PROČ: Majitel může zúžit pohled na jeden apartmán; `null` znamená „všechny vlastněné byty“
/// a nemění se data v repozitáři – jen omezí dotazy v providerech úkolů a rezervací pro daný týden.
final ownerPlanningCalendarApartmentFilterProvider =
    StateProvider<String?>((ref) => null);
