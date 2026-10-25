import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Colour, typography and component tokens for Lawyer's E-Diary.
///
/// This file is the single authoritative token source for the application.
/// It currently carries two token groups:
///
/// 1. The **Modern Legal Editorial** set (`canvas`, `primaryGreen`,
///    `accentGold`, `textPrimary`, `textMuted`, `cardBackground`,
///    `borderLight`, plus the semantic status colours). This is the LED design
///    identity and is the standard every Windows desktop surface is held to.
///
/// 2. The **legacy mobile** set (`background`, `surface`, `ink`, `mutedInk`,
///    `teal`, `deepTeal`, `gold`, `softGold`, `border`, `unread`). These are
///    retained unchanged so the existing Android/mobile screens keep their
///    current appearance. New code must not introduce further reliance on
///    them; migrate to the Modern Legal Editorial tokens instead.
abstract final class AppPalette {
  // -----------------------------------------------------------------------
  // Modern Legal Editorial — canonical LED tokens
  // -----------------------------------------------------------------------

  /// Warm ivory canvas behind every desktop surface.
  static const canvas = Color(0xFFF7F5F2);

  /// Forest green — primary brand and primary action colour.
  static const primaryGreen = Color(0xFF1F3D2B);

  /// Deeper green used for raised brand panels and app bars.
  static const deepGreen = Color(0xFF13382E);

  /// Antique gold — accent, selection and highlight colour.
  static const accentGold = Color(0xFFCCA046);

  /// Charcoal body and heading text.
  static const textPrimary = Color(0xFF1A1A1A);

  /// Warm grey secondary text, captions and metadata.
  static const textMuted = Color(0xFF6B665E);

  /// White card and surface fill.
  static const cardBackground = Color(0xFFFFFFFF);

  /// Warm grey hairline borders and dividers.
  static const borderLight = Color(0xFFE5DFD7);

  // -----------------------------------------------------------------------
  // Semantic status colours
  //
  // A legal workspace needs to distinguish urgent, resolved and advisory
  // states at a glance. These sit alongside the canonical palette and are
  // used consistently instead of the ad-hoc hex values that previously
  // appeared per screen.
  // -----------------------------------------------------------------------

  /// Urgent / overdue / destructive state.
  static const statusDanger = Color(0xFF9A4A3F);

  /// Resolved / settled / positive state.
  static const statusSuccess = Color(0xFF536D5A);

  /// Advisory / pending-amount state.
  static const statusWarning = Color(0xFF9B782B);

  /// Neutral tinted tile fill used behind monochrome status icons.
  static const statusTile = Color(0xFFE9EEE9);

  /// Advisory note panel fill.
  static const noteFill = Color(0xFFFFF7E7);

  /// Advisory note panel border.
  static const noteBorder = Color(0xFFEAD7A6);

  /// Tinted panel fill used behind a destructive or error message.
  static const errorFill = Color(0xFFFFF4E8);

  /// Tinted tile fill used behind a destructive status icon.
  static const statusDangerTile = Color(0xFFF8E8E5);

  /// Darkened destructive colour for text on a light tinted panel.
  static const statusDangerDark = Color(0xFF7B4B1E);

  /// Darkened advisory colour for text on a light tinted panel.
  static const statusWarningDark = Color(0xFF8B6A25);

  /// Muted text intended to sit on a forest-green panel.
  static const onForestMuted = Color(0xFFD8E1D9);

  /// Secondary muted text intended to sit on a forest-green panel.
  static const onForestFaint = Color(0xFFB9C7BD);

  /// Navigation label colour on a forest-green panel.
  static const onForestText = Color(0xFFE3EAE5);

  /// Tinted circular fill used behind a member initial.
  static const onForestTile = Color(0xFFDDE6DE);

  /// Border for a neutral tinted notice panel.
  static const tileBorder = Color(0xFFD5E0D7);

  /// Border colour for a panel that sits on a forest-green background.
  static const onForestBorder = Color(0xFF345640);

  /// Fill of the selected navigation item in the desktop sidebar.
  static const navSelected = Color(0xFF31543D);

  /// Fill of the brand mark tile in the desktop sidebar.
  static const brandTile = Color(0xFF2D513B);

  // -----------------------------------------------------------------------
  // Legacy mobile tokens — retained for Android compatibility
  // -----------------------------------------------------------------------

  static const background = Color(0xFFF5F1E8);
  static const surface = Color(0xFFFFFCF6);
  static const ink = Color(0xFF1E2A2C);
  static const mutedInk = Color(0xFF687170);
  static const teal = Color(0xFF176C68);
  static const deepTeal = Color(0xFF104C4A);
  static const gold = Color(0xFFC89D4D);
  static const softGold = Color(0xFFE6C77E);
  static const border = Color(0xFFE6DED0);
  static const unread = Color(0xFFE46D52);
}

/// Typography helpers for the LED design identity.
///
/// No font files are bundled with the project, so the serif family must
/// resolve from the host platform. On Windows and macOS `Georgia` is a
/// system font and gives the editorial character the design calls for. On
/// Android and Linux the generic `serif` family is used instead, which
/// guarantees a real serif face without introducing an external font
/// dependency.
abstract final class AppTypography {
  /// Serif family used for headings, page titles and the wordmark.
  static String get heading {
    if (kIsWeb) return 'serif';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return 'Palatino Linotype';
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'serif';
    }
  }

  /// Clean sans-serif family used for interface text, labels and tables.
  static String get body {
    if (defaultTargetPlatform == TargetPlatform.windows) return 'Segoe UI';
    return 'sans-serif';
  }
}

/// Component-level tokens shared by the primary action button and the text
/// field.
///
/// These are exposed as a [ThemeExtension] so a shared component can follow
/// whichever visual identity the active platform uses without hardcoding a
/// single colour set. The Android theme keeps the legacy values, the Windows
/// theme uses the Modern Legal Editorial values.
@immutable
class EditorialComponentTheme extends ThemeExtension<EditorialComponentTheme> {
  const EditorialComponentTheme({
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.primaryActionDisabled,
    required this.onPrimaryActionDisabled,
    required this.outlineAction,
    required this.onOutlineAction,
    required this.outlineActionBorder,
    required this.fieldLabel,
    required this.fieldHint,
    required this.fieldText,
    required this.fieldIcon,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldFocusBorder,
  });

  /// Legacy (Android) component tokens.
  static const legacy = EditorialComponentTheme(
    primaryAction: Color(0xFFD4AF37),
    onPrimaryAction: Color(0xDD000000),
    primaryActionDisabled: Color(0x8ED4AF37),
    onPrimaryActionDisabled: Color(0x8D000000),
    outlineAction: Color(0xDD000000),
    onOutlineAction: Color(0xDD000000),
    outlineActionBorder: Color(0x1F000000),
    fieldLabel: Color(0xDD000000),
    fieldHint: Color(0x73000000),
    fieldText: Color(0xDD000000),
    fieldIcon: Color(0xFFD4AF37),
    fieldFill: Color(0xFFFAF8F3),
    fieldBorder: Color(0xFFE9E3D8),
    fieldFocusBorder: Color(0xFFD4AF37),
  );

  /// Modern Legal Editorial (Windows) component tokens.
  static const editorial = EditorialComponentTheme(
    primaryAction: AppPalette.primaryGreen,
    onPrimaryAction: Colors.white,
    primaryActionDisabled: Color(0x8A1F3D2B),
    onPrimaryActionDisabled: Color(0x8AFFFFFF),
    outlineAction: AppPalette.primaryGreen,
    onOutlineAction: AppPalette.primaryGreen,
    outlineActionBorder: AppPalette.borderLight,
    fieldLabel: AppPalette.textPrimary,
    fieldHint: AppPalette.textMuted,
    fieldText: AppPalette.textPrimary,
    fieldIcon: AppPalette.accentGold,
    fieldFill: AppPalette.canvas,
    fieldBorder: AppPalette.borderLight,
    fieldFocusBorder: AppPalette.accentGold,
  );

  final Color primaryAction;
  final Color onPrimaryAction;
  final Color primaryActionDisabled;
  final Color onPrimaryActionDisabled;
  final Color outlineAction;
  final Color onOutlineAction;
  final Color outlineActionBorder;
  final Color fieldLabel;
  final Color fieldHint;
  final Color fieldText;
  final Color fieldIcon;
  final Color fieldFill;
  final Color fieldBorder;
  final Color fieldFocusBorder;

  @override
  EditorialComponentTheme copyWith({
    Color? primaryAction,
    Color? onPrimaryAction,
    Color? primaryActionDisabled,
    Color? onPrimaryActionDisabled,
    Color? outlineAction,
    Color? onOutlineAction,
    Color? outlineActionBorder,
    Color? fieldLabel,
    Color? fieldHint,
    Color? fieldText,
    Color? fieldIcon,
    Color? fieldFill,
    Color? fieldBorder,
    Color? fieldFocusBorder,
  }) {
    return EditorialComponentTheme(
      primaryAction: primaryAction ?? this.primaryAction,
      onPrimaryAction: onPrimaryAction ?? this.onPrimaryAction,
      primaryActionDisabled:
          primaryActionDisabled ?? this.primaryActionDisabled,
      onPrimaryActionDisabled:
          onPrimaryActionDisabled ?? this.onPrimaryActionDisabled,
      outlineAction: outlineAction ?? this.outlineAction,
      onOutlineAction: onOutlineAction ?? this.onOutlineAction,
      outlineActionBorder: outlineActionBorder ?? this.outlineActionBorder,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      fieldHint: fieldHint ?? this.fieldHint,
      fieldText: fieldText ?? this.fieldText,
      fieldIcon: fieldIcon ?? this.fieldIcon,
      fieldFill: fieldFill ?? this.fieldFill,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      fieldFocusBorder: fieldFocusBorder ?? this.fieldFocusBorder,
    );
  }

  @override
  EditorialComponentTheme lerp(
    ThemeExtension<EditorialComponentTheme>? other,
    double t,
  ) {
    if (other is! EditorialComponentTheme) return this;
    return EditorialComponentTheme(
      primaryAction:
          Color.lerp(primaryAction, other.primaryAction, t) ?? primaryAction,
      onPrimaryAction:
          Color.lerp(onPrimaryAction, other.onPrimaryAction, t) ??
          onPrimaryAction,
      primaryActionDisabled:
          Color.lerp(primaryActionDisabled, other.primaryActionDisabled, t) ??
          primaryActionDisabled,
      onPrimaryActionDisabled:
          Color.lerp(
            onPrimaryActionDisabled,
            other.onPrimaryActionDisabled,
            t,
          ) ??
          onPrimaryActionDisabled,
      outlineAction:
          Color.lerp(outlineAction, other.outlineAction, t) ?? outlineAction,
      onOutlineAction:
          Color.lerp(onOutlineAction, other.onOutlineAction, t) ??
          onOutlineAction,
      outlineActionBorder:
          Color.lerp(outlineActionBorder, other.outlineActionBorder, t) ??
          outlineActionBorder,
      fieldLabel: Color.lerp(fieldLabel, other.fieldLabel, t) ?? fieldLabel,
      fieldHint: Color.lerp(fieldHint, other.fieldHint, t) ?? fieldHint,
      fieldText: Color.lerp(fieldText, other.fieldText, t) ?? fieldText,
      fieldIcon: Color.lerp(fieldIcon, other.fieldIcon, t) ?? fieldIcon,
      fieldFill: Color.lerp(fieldFill, other.fieldFill, t) ?? fieldFill,
      fieldBorder: Color.lerp(fieldBorder, other.fieldBorder, t) ?? fieldBorder,
      fieldFocusBorder:
          Color.lerp(fieldFocusBorder, other.fieldFocusBorder, t) ??
          fieldFocusBorder,
    );
  }
}

abstract final class AppTheme {
  /// Legacy light theme used by the Android/mobile surfaces.
  ///
  /// The values are unchanged from the original implementation so the
  /// existing mobile screens keep their current appearance.
  static final light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppPalette.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppPalette.teal,
      brightness: Brightness.light,
      surface: AppPalette.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.background,
      foregroundColor: AppPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerColor: AppPalette.border,
    extensions: const <ThemeExtension<dynamic>>[EditorialComponentTheme.legacy],
  );

  /// Modern Legal Editorial theme used by the Windows desktop application.
  ///
  /// Every surface that is not explicitly styled by a Windows screen falls
  /// back to these values, so dialogs, date pickers, text selection and
  /// progress indicators all follow the LED identity instead of the legacy
  /// teal palette.
  static final windows = ThemeData(
    useMaterial3: true,
    fontFamily: AppTypography.body,
    scaffoldBackgroundColor: AppPalette.canvas,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppPalette.primaryGreen,
          brightness: Brightness.light,
          surface: AppPalette.cardBackground,
        ).copyWith(
          primary: AppPalette.primaryGreen,
          onPrimary: Colors.white,
          secondary: AppPalette.accentGold,
          onSecondary: AppPalette.primaryGreen,
          surface: AppPalette.cardBackground,
          onSurface: AppPalette.textPrimary,
          onSurfaceVariant: AppPalette.textMuted,
          outline: AppPalette.borderLight,
          error: AppPalette.statusDanger,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.canvas,
      foregroundColor: AppPalette.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerColor: AppPalette.borderLight,
    dialogTheme: const DialogThemeData(
      backgroundColor: AppPalette.cardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppPalette.primaryGreen,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    textTheme: _editorialTextTheme,
    extensions: const <ThemeExtension<dynamic>>[
      EditorialComponentTheme.editorial,
    ],
  );

  static final _editorialTextTheme = const TextTheme(
    displaySmall: TextStyle(
      fontFamily: 'Palatino Linotype',
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppPalette.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Georgia',
      fontSize: 27,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppPalette.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Georgia',
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppPalette.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Georgia',
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppPalette.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppPalette.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: AppPalette.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      height: 1.45,
      color: AppPalette.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.45,
      color: AppPalette.textMuted,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppPalette.textPrimary,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: AppPalette.textMuted,
    ),
  );
}
