import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Společný výběr data a času vyzvednutí hotovosti s pravidlem **min. 48 h** od aktuálního okamžiku.
///
/// PROČ: Stejná byznysová logika jako v repozitáři musí platit v modálním formuláři i při změně
/// terménu u pending žádosti – uživatel nesmí zvolit neplatný čas už v UI.
Future<DateTime?> pickOwnerVaultPickupDateTime(
  BuildContext context, {
  DateTime? initialUtc,
}) async {
  final now = DateTime.now();
  final minLocal = now.add(const Duration(hours: 48));
  final firstSelectableDay = DateTime(minLocal.year, minLocal.month, minLocal.day);

  bool dayAllowsPickup(DateTime day) {
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
    return !minLocal.isAfter(endOfDay);
  }

  DateTime initialCalendarDay = firstSelectableDay;
  if (initialUtc != null) {
    final il = initialUtc.toLocal();
    final id = DateTime(il.year, il.month, il.day);
    if (!id.isBefore(firstSelectableDay) && dayAllowsPickup(id)) {
      initialCalendarDay = id;
    }
  }

  final pickedDate = await showDatePicker(
    context: context,
    initialDate: initialCalendarDay,
    firstDate: firstSelectableDay,
    lastDate: now.add(const Duration(days: 366)),
    selectableDayPredicate: dayAllowsPickup,
  );
  if (pickedDate == null || !context.mounted) return null;

  final sameDayAsMin = pickedDate.year == minLocal.year &&
      pickedDate.month == minLocal.month &&
      pickedDate.day == minLocal.day;
  final initialTod = sameDayAsMin
      ? TimeOfDay.fromDateTime(minLocal)
      : const TimeOfDay(hour: 9, minute: 0);

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: initialTod,
  );
  if (pickedTime == null || !context.mounted) return null;

  final combinedLocal = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );

  if (combinedLocal.isBefore(minLocal)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('owner.cash_disposition_validation_pickup_48h'.tr())),
    );
    return null;
  }

  return combinedLocal.toUtc();
}
