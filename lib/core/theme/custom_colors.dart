import 'package:flutter/material.dart';

/// Sémantické barvy nad rámec Material 3 [ColorScheme] (kde je pouze [ColorScheme.error]).
///
/// PROČ: Jednotné „success / warning / info“ pro SnackBary, štítky a empty states
/// bez rozptýlených `Colors.green` napříč features. Rozšíření tématu zůstává v core.
@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.success,
    required this.successSubtle,
    required this.onSuccess,
    required this.warning,
    required this.warningSubtle,
    required this.onWarning,
    required this.info,
    required this.infoSubtle,
    required this.onInfo,
    required this.groupTypeBlue,
    required this.groupTypePurple,
    required this.modalBarrier,
  });

  /// Pozadí / kontury úspěšné akce (uloženo, synchronizováno).
  final Color success;

  /// Jemné pozadí pro úspěšný stav (badge/chip/panel bez agresivního kontrastu).
  ///
  /// PROČ: V admin widgetech často potřebujeme „pozitivní“ kontext bez toho,
  /// aby UI působilo jako finální potvrzovací alert.
  final Color successSubtle;

  /// Text a ikony na [success].
  final Color onSuccess;

  /// Varování (upozornění bez chyby, čekající stav).
  final Color warning;

  /// Jemné pozadí varování.
  ///
  /// PROČ: U „needs attention“ panelů a informačních boxů nechceme použít
  /// plnou warning barvu, aby nedocházelo k vizuálnímu přetížení.
  final Color warningSubtle;

  /// Text a ikony na [warning].
  final Color onWarning;

  /// Informativní zvýraznění (nápověda, tip).
  final Color info;

  /// Jemné pozadí informačního stavu.
  ///
  /// PROČ: Stabilní informační panely (např. tooltip-like boxy) mají mít
  /// konzistentní jemné pozadí v light i dark režimu.
  final Color infoSubtle;

  /// Text a ikony na [info].
  final Color onInfo;

  /// Kategorie/typ skupiny – modrá varianta.
  ///
  /// PROČ: V přehledových seznamech (např. payout history) odlišujeme typy
  /// entit barvou, ale chceme je řídit centrálně.
  final Color groupTypeBlue;

  /// Kategorie/typ skupiny – fialová varianta.
  ///
  /// PROČ: Druhá sémantická skupinová barva pro odlišení datových bloků.
  final Color groupTypePurple;

  /// Výchozí overlay pro modal barrier.
  ///
  /// PROČ: Jednotný „závoj“ modalů napříč admin widgety bez hardcoded
  /// `Colors.black54` v jednotlivých obrazovkách.
  final Color modalBarrier;

  /// Výchozí paleta pro světlé téma (dostatečný kontrast k bílému/jemnému pozadí).
  static const CustomColors light = CustomColors(
    success: Color(0xFF2E7D32),
    successSubtle: Color(0xFFE8F5E9),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFFE65100),
    warningSubtle: Color(0xFFFFF3E0),
    onWarning: Color(0xFFFFFFFF),
    info: Color(0xFF1565C0),
    infoSubtle: Color(0xFFE3F2FD),
    onInfo: Color(0xFFFFFFFF),
    groupTypeBlue: Color(0xFF1565C0),
    groupTypePurple: Color(0xFF6A1B9A),
    modalBarrier: Color(0x8A000000),
  );

  /// Paleta pro tmavé téma (světlejší odstíny na tmavém pozadí).
  static const CustomColors dark = CustomColors(
    success: Color(0xFF81C784),
    successSubtle: Color(0xFF1B5E20),
    onSuccess: Color(0xFF1B5E20),
    warning: Color(0xFFFFB74D),
    warningSubtle: Color(0xFF5D4037),
    onWarning: Color(0xFF3E2723),
    info: Color(0xFF64B5F6),
    infoSubtle: Color(0xFF0D47A1),
    onInfo: Color(0xFF0D47A1),
    groupTypeBlue: Color(0xFF64B5F6),
    groupTypePurple: Color(0xFFCE93D8),
    modalBarrier: Color(0x8A000000),
  );

  @override
  CustomColors copyWith({
    Color? success,
    Color? successSubtle,
    Color? onSuccess,
    Color? warning,
    Color? warningSubtle,
    Color? onWarning,
    Color? info,
    Color? infoSubtle,
    Color? onInfo,
    Color? groupTypeBlue,
    Color? groupTypePurple,
    Color? modalBarrier,
  }) {
    return CustomColors(
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      onInfo: onInfo ?? this.onInfo,
      groupTypeBlue: groupTypeBlue ?? this.groupTypeBlue,
      groupTypePurple: groupTypePurple ?? this.groupTypePurple,
      modalBarrier: modalBarrier ?? this.modalBarrier,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) return this;
    return CustomColors(
      success: Color.lerp(success, other.success, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSubtle: Color.lerp(infoSubtle, other.infoSubtle, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      groupTypeBlue: Color.lerp(groupTypeBlue, other.groupTypeBlue, t)!,
      groupTypePurple: Color.lerp(groupTypePurple, other.groupTypePurple, t)!,
      modalBarrier: Color.lerp(modalBarrier, other.modalBarrier, t)!,
    );
  }
}
