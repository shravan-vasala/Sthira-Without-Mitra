import 'package:flutter/material.dart';
import 'app_colors.dart';

extension AppTypographyExtension on BuildContext {
  AppTypography get text => AppTypography(this);
}

class AppTypography {
  final BuildContext context;

  AppTypography(this.context);

  TextStyle get display => TextStyle(
        fontFamily: 'Cabinet Grotesk',
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.0,
        color: context.colors.textDark,
      );

  TextStyle get titleLarge => TextStyle(
        fontFamily: 'Cabinet Grotesk',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: context.colors.textDark,
      );

  TextStyle get title => TextStyle(
        fontFamily: 'Cabinet Grotesk',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: context.colors.textDark,
      );

  TextStyle get body => TextStyle(
        fontFamily: 'General Sans',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: context.colors.textMedium,
      );

  TextStyle get bodyBold => TextStyle(
        fontFamily: 'General Sans',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.colors.textDark,
      );

  TextStyle get caption => TextStyle(
        fontFamily: 'General Sans',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.textLight,
      );

  TextStyle get label => TextStyle(
        fontFamily: 'General Sans',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: context.colors.textLight,
      );
}
