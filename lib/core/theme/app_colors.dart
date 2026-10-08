import 'package:flutter/material.dart';

/// Charte Exim Bank.
/// [brandBlue] et [brandGold] sont relevés sur le logo officiel ; [navy] et [gold]
/// viennent de l'app Exim actuelle (fonds sombres et accents).
class AppColors {
  AppColors._();

  // Logo officiel
  static const brandBlue = Color(0xFF19398A);
  static const brandGold = Color(0xFF847650);

  // Interface
  static const navy = Color(0xFF0B2A6B);
  static const navyDark = Color(0xFF071C4A);
  static const gold = Color(0xFFC9A04A);
  static const goldLight = Color(0xFFF3E7CB);

  // Équivalents des pastilles Wise (vert vif / vert pâle)
  static const primary = navy;
  static const onPrimary = Colors.white;
  static const primarySoft = Color(0xFFE3E9F6);
  static const onPrimarySoft = navy;

  // Neutres
  static const background = Colors.white;
  static const surface = Color(0xFFF2F4F7);
  static const surfaceAlt = Color(0xFFE8EBF0);
  static const border = Color(0xFFD9DDE4);
  static const textPrimary = Color(0xFF0E0F0C);
  static const textSecondary = Color(0xFF5D6470);
  static const textMuted = Color(0xFF8A919C);

  // États
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
}
