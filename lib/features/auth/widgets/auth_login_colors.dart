import 'package:flutter/material.dart';

/// Firemní barvy přihlášení FalcoNest (formulář, akcenty tlačítek).
///
/// PROČ: Oddělené od obrazovky kvůli SRP – sdílí je [AuthTextField] i [AuthLayout].
class AuthLoginColors {
  AuthLoginColors._();

  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color accentOrange = Color(0xFFE65100);
}

/// Šířka od které se zobrazí split-screen (levá grafika, pravá karta).
const double kAuthLoginSplitBreakpoint = 800;
