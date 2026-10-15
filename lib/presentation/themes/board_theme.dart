import 'package:flutter/material.dart';

enum BoardThemeType {
  darkModern,
  classicWood,
  cyberNeon,
  royalMarble;

  String get displayName {
    switch (this) {
      case BoardThemeType.darkModern:
        return 'Dark Modern';
      case BoardThemeType.classicWood:
        return 'Classic Wood';
      case BoardThemeType.cyberNeon:
        return 'Cyber Neon';
      case BoardThemeType.royalMarble:
        return 'Royal Marble';
    }
  }
}

/// Visual theme specification for board and surrounding UI.
class BoardTheme {
  final BoardThemeType type;
  final Color boardBg;
  final Color gridLine;
  final Color starColor;
  final Color scaffoldBg;
  final Color hudBg;
  final Color outerBorder;
  final Color yardContainerBg;

  const BoardTheme({
    required this.type,
    required this.boardBg,
    required this.gridLine,
    required this.starColor,
    required this.scaffoldBg,
    required this.hudBg,
    required this.outerBorder,
    required this.yardContainerBg,
  });

  static const BoardTheme darkModern = BoardTheme(
    type: BoardThemeType.darkModern,
    boardBg: Color(0xFFF8FAFC),
    gridLine: Color(0xFFCBD5E1),
    starColor: Color(0xFFF59E0B),
    scaffoldBg: Color(0xFF0F172A),
    hudBg: Color(0xFF1E293B),
    outerBorder: Color(0xFF1E293B),
    yardContainerBg: Colors.white,
  );

  static const BoardTheme classicWood = BoardTheme(
    type: BoardThemeType.classicWood,
    boardBg: Color(0xFFF5EBE0),
    gridLine: Color(0xFFB08968),
    starColor: Color(0xFFD4AF37), // Metallic Gold
    scaffoldBg: Color(0xFF3E2723), // Dark Walnut
    hudBg: Color(0xFF4E342E),
    outerBorder: Color(0xFF2D1810),
    yardContainerBg: Color(0xFFFFF8E7),
  );

  static const BoardTheme cyberNeon = BoardTheme(
    type: BoardThemeType.cyberNeon,
    boardBg: Color(0xFF090D16),
    gridLine: Color(0xFF1E293B),
    starColor: Color(0xFF38BDF8), // Electric Cyan
    scaffoldBg: Color(0xFF030712), // Pitch Black
    hudBg: Color(0xFF0F172A),
    outerBorder: Color(0xFF38BDF8),
    yardContainerBg: Color(0xFF111827),
  );

  static const BoardTheme royalMarble = BoardTheme(
    type: BoardThemeType.royalMarble,
    boardBg: Color(0xFFFFFFFF),
    gridLine: Color(0xFFE2E8F0),
    starColor: Color(0xFFEAB308),
    scaffoldBg: Color(0xFF1E1E24),
    hudBg: Color(0xFF2B2D42),
    outerBorder: Color(0xFF64748B),
    yardContainerBg: Color(0xFFF8FAFC),
  );

  static BoardTheme fromType(BoardThemeType type) {
    switch (type) {
      case BoardThemeType.darkModern:
        return darkModern;
      case BoardThemeType.classicWood:
        return classicWood;
      case BoardThemeType.cyberNeon:
        return cyberNeon;
      case BoardThemeType.royalMarble:
        return royalMarble;
    }
  }
}
