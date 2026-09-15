import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Sthira type scale. 10 tokens total.
///
/// RULES FOR THIS FILE:
/// 1. context.text.* must be the dominant path.
/// 2. Fewer than 60 remaining inline TextStyle( literals in lib/, all color-only copyWith.
/// 3. If you find yourself writing .copyWith(fontSize: ...), the token set is wrong.
///    Stop and report it. Do not add an 11th size.
extension AppTypographyExtension on BuildContext {
  AppTypography get text => AppTypography(colors);
}

class AppTypography {
  final AppColorsPalette colors;

  AppTypography(this.colors);

  /// THE one hero number on a screen. Max one per screen.
  TextStyle get metric => TextStyle(
    fontFamily: 'Cabinet Grotesk',
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    height: 1.0,
    color: colors.textDark,
  );

  /// Large numeric readouts in cards and dialogs
  TextStyle get display => TextStyle(
    fontFamily: 'Cabinet Grotesk',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.05,
    color: colors.textDark,
  );

  /// AppBar titles, sheet titles, the Home greeting
  TextStyle get screenTitle => TextStyle(
    fontFamily: 'Cabinet Grotesk',
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
    color: colors.textDark,
  );

  /// Card / tile titles
  TextStyle get cardTitle => TextStyle(
    fontFamily: 'Cabinet Grotesk',
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
    color: colors.textDark,
  );

  /// SectionHeader — colored primary per the design system
  TextStyle get sectionLabel => TextStyle(
    fontFamily: 'Cabinet Grotesk',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.2,
    color: colors.primary,
  );

  /// UPPERCASE micro-labels above a group
  TextStyle get eyebrow => TextStyle(
    fontFamily: 'General Sans',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
    color: colors.textMedium,
  );

  /// Reading text
  TextStyle get body => TextStyle(
    fontFamily: 'General Sans',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.45,
    color: colors.textDark,
  );

  /// List-row titles, emphasized body
  TextStyle get bodyStrong => TextStyle(
    fontFamily: 'General Sans',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.4,
    color: colors.textDark,
  );

  /// Metadata, subtitles under a title
  TextStyle get caption => TextStyle(
    fontFamily: 'General Sans',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
    color: colors.textMedium,
  );

  /// Pills, badges, chart axis labels
  TextStyle get micro => TextStyle(
    fontFamily: 'General Sans',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
    color: colors.textMedium,
  );
}
