import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CampusConnect AUS design system.
///
/// Single source of truth for all visual design tokens: colors, typography,
/// spacing, and component themes. Every screen and widget in the application
/// derives its appearance from this class.
///
/// **Brand specification:**
/// - Primary: `#880E4F` — Deep Maroon (AppBar, buttons, SOS elements)
/// - Secondary: `#00B0FF` — Vivid Light Blue (indicators, tab selection)
/// - Background: `#121212` — Dark Surface Matte (OLED optimized)
/// - Text: `#FFFFFF` — High Emission White
/// - WCAG 2.1 contrast ratio: ≥ 4.5:1
///
/// **Usage:**
/// ```dart
/// MaterialApp(theme: AppTheme.dark)
/// ```
abstract final class AppTheme {
  // ── Brand Color Palette ───────────────────────────────────────────────────

  /// Deep Maroon — primary brand color.
  ///
  /// Applied to: AppBar, primary buttons, splash banner, SOS trigger elements.
  static const Color primary = Color(0xFF880E4F);

  /// Light Maroon — slightly lighter variant for hover/pressed states.
  static const Color primaryLight = Color(0xFFAD1457);

  /// Dark Maroon — for shadows and deep accents.
  static const Color primaryDark = Color(0xFF560027);

  /// Vivid Light Blue — secondary accent color.
  ///
  /// Applied to: tab selection indicators, map routing overlays,
  /// unread message badges, real-time typing indicators.
  static const Color secondary = Color(0xFF00B0FF);

  /// Darker blue for secondary pressed states.
  static const Color secondaryDark = Color(0xFF0081CB);

  /// Dark Surface Matte — primary background canvas.
  ///
  /// OLED-optimized true black (#121212) to reduce battery drain
  /// on modern mobile displays.
  static const Color background = Color(0xFF121212);

  /// Slightly elevated surface (cards, bottom sheets, nav bars).
  static const Color surface = Color(0xFF1E1E1E);

  /// Card surface color — slightly lighter than surface.
  static const Color cardSurface = Color(0xFF252525);

  /// Input field fill color.
  static const Color inputFill = Color(0xFF2C2C2C);

  /// High-emission white — primary text and icon color.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Muted grey — secondary text, hints, and disabled states.
  static const Color textSecondary = Color(0xFFB0B0B0);

  /// Very muted — for dividers and subtle borders.
  static const Color textDisabled = Color(0xFF555555);

  /// Error / destructive — validation failures and alerts.
  static const Color error = Color(0xFFCF6679);

  /// Success / confirmation — positive state indicators.
  static const Color success = Color(0xFF4CAF50);

  /// Warning — caution states (SOS countdown, time-limited actions).
  static const Color warning = Color(0xFFFFB300);

  // ── Spacing ───────────────────────────────────────────────────────────────

  /// 4px — micro spacing (icon padding, thin gaps)
  static const double spaceXS = 4.0;

  /// 8px — small spacing (compact list items)
  static const double spaceSM = 8.0;

  /// 16px — standard spacing (card padding, section gaps)
  static const double spaceMD = 16.0;

  /// 24px — large spacing (screen horizontal padding)
  static const double spaceLG = 24.0;

  /// 32px — extra-large spacing (section separators)
  static const double spaceXL = 32.0;

  /// 48px — hero spacing (splash logo area)
  static const double spaceXXL = 48.0;

  // ── Border Radii ─────────────────────────────────────────────────────────

  /// 8px — small radius for chips and small elements
  static const double radiusSM = 8.0;

  /// 12px — standard radius for input fields and buttons
  static const double radiusMD = 12.0;

  /// 16px — large radius for cards and sheets
  static const double radiusLG = 16.0;

  /// 24px — extra-large radius for bottom sheets
  static const double radiusXL = 24.0;

  // ── Typography ────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme() {
    return GoogleFonts.outfitTextTheme(
      const TextTheme(
        // Display — hero text on splash and major headings
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: onPrimary,
          letterSpacing: -1.0,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: onPrimary,
          letterSpacing: -0.5,
        ),

        // Headlines — screen titles and section headers
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: onPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onPrimary,
        ),

        // Titles — card titles and list item headers
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: onPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),

        // Body — main content text
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: onPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),

        // Labels — buttons, tabs, badges
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onPrimary,
          letterSpacing: 0.3,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onPrimary,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Full Dark ThemeData ───────────────────────────────────────────────────

  /// The complete Material 3 dark [ThemeData] for CampusConnect AUS.
  ///
  /// Pass this directly to [MaterialApp.theme].
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        // Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: primaryDark,
          secondary: secondary,
          onSecondary: onPrimary,
          secondaryContainer: secondaryDark,
          surface: surface,
          onSurface: onPrimary,
          error: error,
          onError: onPrimary,
        ),

        scaffoldBackgroundColor: background,
        textTheme: _buildTextTheme(),
        primaryTextTheme: _buildTextTheme(),

        // AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 2,
          shadowColor: primaryDark.withAlpha(128),
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onPrimary,
          ),
          iconTheme: const IconThemeData(color: onPrimary),
        ),

        // Bottom Navigation Bar
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: secondary,
          unselectedItemColor: textSecondary,
          selectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),

        // Navigation Drawer (admin)
        navigationDrawerTheme: const NavigationDrawerThemeData(
          backgroundColor: surface,
          indicatorColor: primaryDark,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
          ),
        ),

        // Elevated Button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: onPrimary,
            disabledBackgroundColor: textDisabled,
            disabledForegroundColor: textSecondary,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(
              horizontal: spaceLG,
              vertical: spaceMD,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMD),
            ),
            elevation: 0,
            textStyle: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),

        // Outlined Button
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: secondary,
            side: const BorderSide(color: secondary, width: 1.5),
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(
              horizontal: spaceLG,
              vertical: spaceMD,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMD),
            ),
            textStyle: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Text Button
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: secondary,
            textStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Input Fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMD),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMD),
            borderSide: BorderSide(
              color: textDisabled.withAlpha(128),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMD),
            borderSide: const BorderSide(color: secondary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMD),
            borderSide: const BorderSide(color: error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMD),
            borderSide: const BorderSide(color: error, width: 2),
          ),
          labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
          hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
          errorStyle: const TextStyle(color: error, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: spaceMD,
            vertical: spaceMD,
          ),
          prefixIconColor: textSecondary,
          suffixIconColor: textSecondary,
        ),

        // Cards
        cardTheme: CardThemeData(
          color: cardSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLG),
          ),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),

        // FAB (SOS button)
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 6,
          shape: CircleBorder(),
        ),

        // Dividers
        dividerTheme: DividerThemeData(
          color: textDisabled.withAlpha(80),
          thickness: 1,
          space: 1,
        ),

        // SnackBar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: cardSurface,
          contentTextStyle: const TextStyle(
            color: onPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          actionTextColor: secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          behavior: SnackBarBehavior.floating,
          elevation: 4,
        ),

        // Chips (for category filters in Marketplace)
        chipTheme: ChipThemeData(
          backgroundColor: inputFill,
          selectedColor: primary,
          disabledColor: textDisabled,
          labelStyle: const TextStyle(
            color: onPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: spaceSM),
        ),

        // List Tiles
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          iconColor: textSecondary,
          textColor: onPrimary,
          contentPadding: EdgeInsets.symmetric(
            horizontal: spaceMD,
            vertical: spaceXS,
          ),
        ),

        // Icon
        iconTheme: const IconThemeData(
          color: onPrimary,
          size: 24,
        ),

        // Progress Indicator
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: secondary,
          linearTrackColor: inputFill,
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusXL),
          ),
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onPrimary,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14,
            color: textSecondary,
            height: 1.5,
          ),
        ),

        // Bottom Sheet
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(radiusXL),
            ),
          ),
          elevation: 8,
        ),
      );
}
