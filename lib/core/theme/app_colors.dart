import 'package:flutter/material.dart';

/// Minimal color palette: white surface, grey scale text, one accent color.
///
/// Do not hardcode colors inside widgets; always reference this palette so a
/// future design-system change stays a one-file edit.
abstract final class AppColors {
  static const Color accent = Color(0xFF0D9488);
  static const Color accentSoft = Color(0xFFE7F5F1);

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F7F8);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFE5E7EB);

  static const Color darkCard = Color(0xFF111827);
  static const Color onDarkPrimary = Color(0xFFFFFFFF);
  static const Color onDarkSecondary = Color(0x99FFFFFF);

  static const Color myMessageBubble = Color(0xFF111827);
  static const Color myMessageText = Color(0xFFFFFFFF);
  static const Color otherMessageBubble = Color(0xFFF3F4F6);
}
