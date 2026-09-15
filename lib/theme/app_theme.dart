import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextStyle numeric(TextStyle base) => base.copyWith(
    fontFeatures: [...?base.fontFeatures, const FontFeature.tabularFigures()],
  );

  static ThemeData get light {
    final colors = AppColorsLight();
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'General Sans',
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsLight().scaffoldBg,
      primaryColor: AppColorsLight().primary,
      colorScheme: ColorScheme.light(
        primary: AppColorsLight().primary,
        secondary: AppColorsLight().indigo,
        surface: AppColorsLight().white,
        error: AppColorsLight().red,
        onPrimary: AppColorsLight().white,
        onSecondary: AppColorsLight().white,
        onSurface: AppColorsLight().textDark,
        onError: colors.white,
      ),
      textTheme: _buildTextTheme(
        textDark: colors.textDark,
        textMedium: colors.textMedium,
        textLight: colors.textLight,
        primary: colors.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: AppColorsLight().card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: AppColorsLight().textDark.withValues(alpha: 0.03),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        backgroundColor: AppColorsLight().scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColorsLight().textDark,
        ),
        iconTheme: IconThemeData(color: AppColorsLight().textDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColorsLight().white,
        selectedItemColor: AppColorsLight().primary,
        unselectedItemColor: AppColorsLight().textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsLight().primary,
          foregroundColor: AppColorsLight().onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsLight().primary,
          side: BorderSide(color: AppColorsLight().primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColorsLight().card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColorsLight().card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsLight().card,
        contentTextStyle: TextStyle(
          fontFamily: 'General Sans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColorsLight().textDark,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsLight().inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColorsLight().primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(
          color: AppColorsLight().textMedium,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColorsLight().primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: AppColorsLight().textLight, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(
        color: AppColorsLight().divider,
        thickness: 1,
        space: 0,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColorsLight().green;
          }
          return Colors.transparent;
        }),
        shape: const CircleBorder(),
        side: BorderSide(color: AppColorsLight().border, width: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsLight().card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColorsLight().textDark,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'General Sans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColorsLight().textMedium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: AppColorsLight().textDark, fontSize: 14),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColorsLight().card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColorsLight().textDark,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColorsLight().textMedium,
        ),
        iconColor: AppColorsLight().textMedium,
      ),
      canvasColor: AppColorsLight().card,
      popupMenuTheme: PopupMenuThemeData(
        color: AppColorsLight().card,
        textStyle: TextStyle(color: AppColorsLight().textDark),
      ),
    );
  }

  static ThemeData get dark {
    final colors = AppColorsDark();
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'General Sans',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorsDark().scaffoldBg,
      primaryColor: AppColorsDark().primary,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme.dark(
        primary: AppColorsDark().primary,
        secondary: AppColorsDark().indigo,
        surface: AppColorsDark().surface,
        error: AppColorsDark().red,
        onPrimary: AppColorsDark().onPrimary,
        onSecondary: AppColorsDark().onPrimary,
        onSurface: AppColorsDark().onSurface,
        onError: colors.onPrimary,
      ),
      textTheme: _buildTextTheme(
        textDark: colors.textDark,
        textMedium: colors.textMedium,
        textLight: colors.textLight,
        primary: colors.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: AppColorsDark().card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: AppColorsDark().textDark.withValues(alpha: 0.03),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: AppColorsDark().scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColorsDark().textDark,
        ),
        iconTheme: IconThemeData(color: AppColorsDark().textDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColorsDark().card,
        selectedItemColor: AppColorsDark().primary,
        unselectedItemColor: AppColorsDark().textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsDark().primary,
          foregroundColor: AppColorsDark().onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark().primary,
          side: BorderSide(color: AppColorsDark().primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColorsDark().card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColorsDark().card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsDark().card,
        contentTextStyle: TextStyle(
          fontFamily: 'General Sans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColorsDark().textDark,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark().inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColorsDark().border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColorsDark().primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(
          color: AppColorsDark().textMedium,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColorsDark().primaryLight,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: AppColorsDark().textLight, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(
        color: AppColorsDark().divider,
        thickness: 1,
        space: 0,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColorsDark().green;
          }
          return Colors.transparent;
        }),
        shape: const CircleBorder(),
        side: BorderSide(color: AppColorsDark().border, width: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsDark().card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColorsDark().textDark,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'General Sans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColorsDark().textMedium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: AppColorsDark().textDark, fontSize: 14),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColorsDark().card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColorsDark().textDark,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColorsDark().textMedium,
        ),
        iconColor: AppColorsDark().textMedium,
      ),
      canvasColor: AppColorsDark().card,
      popupMenuTheme: PopupMenuThemeData(
        color: AppColorsDark().card,
        textStyle: TextStyle(color: AppColorsDark().textDark),
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required Color textDark,
    required Color textMedium,
    required Color textLight,
    required Color primary,
  }) {
    final metric = TextStyle(
      fontFamily: 'Cabinet Grotesk',
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.6,
      height: 1.0,
      color: textDark,
    );
    final display = TextStyle(
      fontFamily: 'Cabinet Grotesk',
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      height: 1.05,
      color: textDark,
    );
    final screenTitle = TextStyle(
      fontFamily: 'Cabinet Grotesk',
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.15,
      color: textDark,
    );
    final cardTitle = TextStyle(
      fontFamily: 'Cabinet Grotesk',
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.25,
      color: textDark,
    );
    final sectionLabel = TextStyle(
      fontFamily: 'Cabinet Grotesk',
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      height: 1.2,
      color: primary,
    );
    final eyebrow = TextStyle(
      fontFamily: 'General Sans',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      height: 1.2,
      color: textMedium,
    );
    final body = TextStyle(
      fontFamily: 'General Sans',
      fontSize: 15,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.45,
      color: textDark,
    );
    final bodyStrong = TextStyle(
      fontFamily: 'General Sans',
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      height: 1.4,
      color: textDark,
    );
    final caption = TextStyle(
      fontFamily: 'General Sans',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
      color: textMedium,
    );
    final micro = TextStyle(
      fontFamily: 'General Sans',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.2,
      color: textMedium,
    );

    return TextTheme(
      displayLarge: metric,
      displayMedium: display,
      displaySmall: screenTitle,
      headlineLarge: display,
      headlineMedium: screenTitle,
      headlineSmall: cardTitle,
      titleLarge: cardTitle,
      titleMedium: bodyStrong,
      titleSmall: caption,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: bodyStrong,
      labelMedium: caption,
      labelSmall: micro,
    ).apply(
      bodyColor: textDark,
      displayColor: textDark,
    );
  }
}
