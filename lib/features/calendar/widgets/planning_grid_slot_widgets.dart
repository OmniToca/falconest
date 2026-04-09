import 'package:flutter/material.dart';

/// Společná výška 15min slotu pro admin i owner plánovací kalendář.
///
/// PROČ samostatný soubor: const [PlanningGridDaySlotDivider] a prázdné časové řádky
/// se při rebuildu nemění – Flutter může sdílet jednu instanci místo 600+ nových widgetů.
const double kPlanningGridSlotHeight = 18;

/// Jedna vodorovná linka pod 15min slotem – plně const (odpovídá dřívějšímu šedému mřížkování).
class PlanningGridDaySlotDivider extends StatelessWidget {
  const PlanningGridDaySlotDivider({super.key});

  /// Sladěno s původním `Colors.grey` + alpha na jemnou linku 0.5px.
  static const Color _line = Color(0x66999999);

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: kPlanningGridSlotHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _line, width: 0.5)),
        ),
      ),
    );
  }
}

/// Prázdný řádek v časové ose (bez celohodinového popisku).
class PlanningGridTimeEmptySlot extends StatelessWidget {
  const PlanningGridTimeEmptySlot({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: kPlanningGridSlotHeight);
}

/// Sloupec jednoho dne: pravý okraj + sloupec const dividerů.
class PlanningGridDayColumn extends StatelessWidget {
  const PlanningGridDayColumn({
    super.key,
    required this.width,
    required this.slotCount,
  });

  final double width;
  final int slotCount;

  static const BorderSide _vertical = BorderSide(color: Color(0x40999999));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(border: Border(right: _vertical)),
      child: Column(
        children: List<Widget>.generate(
          slotCount,
          (_) => const PlanningGridDaySlotDivider(),
        ),
      ),
    );
  }
}

/// Hodinový popisek v levém sloupci času.
class PlanningGridTimeLabeledSlot extends StatelessWidget {
  const PlanningGridTimeLabeledSlot({
    super.key,
    required this.hour,
    required this.minute,
  });

  final int hour;
  final int minute;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kPlanningGridSlotHeight,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 4, top: 0),
          child: Text(
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}
