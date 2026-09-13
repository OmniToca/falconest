import 'package:flutter/material.dart';

/// [IndexedStack] s odloženým mountem – děti se vytvoří až při prvním zobrazení indexu.
///
/// PROČ: Klasický [IndexedStack] mountuje všechny [children] hned při prvním buildu rodiče.
/// U Admin/Owner layoutu to spouští desítky Riverpod providerů a Supabase dotazů naráz,
/// i když uživatel vidí jen jednu záložku. [LazyIndexedStack] odloží build neaktivních tabů
/// až do první návštěvy; po načtení zůstanou v paměti přes [Offstage], takže se neztratí
/// scroll pozice ani stav formulářů (stejný princip jako u původního IndexedStack).
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.sizing = StackFit.loose,
  });

  /// Index právě zobrazené záložky (stejná sémantika jako u [IndexedStack]).
  final int index;

  /// Seznam obrazovek – délka musí být stabilní po dobu života widgetu.
  final List<Widget> children;

  /// Zarovnání vnitřního [Stack]u (parita s [IndexedStack]).
  final AlignmentGeometry alignment;

  /// [StackFit] vnitřního [Stack]u (parita s [IndexedStack]).
  final StackFit sizing;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  /// Indexy záložek, které už byly alespoň jednou navštíveny – drží se v paměti.
  late Set<int> _visitedIndices;

  int _clampIndex(int raw) {
    if (widget.children.isEmpty) return 0;
    return raw.clamp(0, widget.children.length - 1);
  }

  @override
  void initState() {
    super.initState();
    // PROČ: Výchozí tab musí být mountnutý hned – jinak by první obrazovka nebyla vidět.
    _visitedIndices = {_clampIndex(widget.index)};
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clamped = _clampIndex(widget.index);
    if (!_visitedIndices.contains(clamped)) {
      setState(() {
        _visitedIndices = {..._visitedIndices, clamped};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeIndex = _clampIndex(widget.index);

    // PROČ bez Positioned.fill: nativní [IndexedStack] jen balí děti do [Offstage].
    // Positioned.fill u Stacku bez pevných rozměrů (typicky na webu v Expanded) způsobí
    // kolaps layoutu – šedá prázdná plocha místo obsahu záložky.
    return Stack(
      fit: widget.sizing,
      alignment: widget.alignment,
      textDirection: Directionality.maybeOf(context),
      children: List.generate(widget.children.length, (i) {
        if (!_visitedIndices.contains(i)) {
          return const SizedBox.shrink();
        }
        return Offstage(
          offstage: activeIndex != i,
          child: KeyedSubtree(
            key: ValueKey<int>(i),
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}
