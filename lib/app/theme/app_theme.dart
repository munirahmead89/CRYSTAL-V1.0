import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The three and only three colors Crystal Messenger is allowed to use.
///
///   - Pure Black  #000000 — surfaces, text on green
///   - Pure White  #FFFFFF — text/graphics on black, bright surfaces
///   - Crystal Green  #00E676 — the single accent (brand, actions, receipts)
///
/// Every design token below is derived from (or a transparency blend of)
/// these three hues. No other hue is permitted anywhere in the UI.
abstract final class CrystalColors {
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Softened from pure #00FF00 to Material Green A400 — less harsh on OLED
  // dark screens while remaining unmistakably the Crystal brand color.
  static const Color green = Color(0xFF00E676);

  // Dark green (A700 family) for unread-count badges so the count stays
  // readable on both black and white surfaces, WhatsApp-style.
  static const Color greenDark = Color(0xFF00BF55);

  // Transparency blends of the pure hues (share the same RGBA hue space).
  static const Color white60 = Color(0x99FFFFFF);
  static const Color white40 = Color(0x66FFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white12 = Color(0x1FFFFFFF);

  static const Color black60 = Color(0x99000000);
  static const Color black40 = Color(0x66000000);
  static const Color black24 = Color(0x3D000000);
  static const Color black12 = Color(0x1F000000);

  static const Color green60 = Color(0x9900E676);
  static const Color green40 = Color(0x6600E676);
  static const Color green24 = Color(0x3D00E676);
  static const Color green12 = Color(0x1F00E676);
}

abstract final class AppTheme {
  static ThemeData get light => _base(_lightScheme, _lightTokens);

  static ThemeData get dark => _base(_darkScheme, _darkTokens);

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: CrystalColors.green,
    onPrimary: CrystalColors.black,
    primaryContainer: CrystalColors.green24,
    onPrimaryContainer: CrystalColors.white,
    secondary: CrystalColors.white,
    onSecondary: CrystalColors.black,
    secondaryContainer: CrystalColors.white24,
    onSecondaryContainer: CrystalColors.white,
    tertiary: CrystalColors.green,
    onTertiary: CrystalColors.black,
    tertiaryContainer: CrystalColors.green12,
    onTertiaryContainer: CrystalColors.white,
    error: CrystalColors.white,
    onError: CrystalColors.black,
    errorContainer: CrystalColors.white24,
    onErrorContainer: CrystalColors.white,
    surface: CrystalColors.black,
    onSurface: CrystalColors.white,
    surfaceContainerHighest: CrystalColors.white12,
    onSurfaceVariant: CrystalColors.white60,
    outline: CrystalColors.white40,
    outlineVariant: CrystalColors.white12,
    shadow: CrystalColors.black,
    scrim: CrystalColors.black,
    inverseSurface: CrystalColors.white,
    onInverseSurface: CrystalColors.black,
    inversePrimary: CrystalColors.black,
    surfaceTint: CrystalColors.green,
  );

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: CrystalColors.green,
    onPrimary: CrystalColors.black,
    primaryContainer: CrystalColors.green24,
    onPrimaryContainer: CrystalColors.black,
    secondary: CrystalColors.black,
    onSecondary: CrystalColors.white,
    secondaryContainer: CrystalColors.black12,
    onSecondaryContainer: CrystalColors.black,
    tertiary: CrystalColors.green,
    onTertiary: CrystalColors.black,
    tertiaryContainer: CrystalColors.green12,
    onTertiaryContainer: CrystalColors.black,
    error: CrystalColors.black,
    onError: CrystalColors.white,
    errorContainer: CrystalColors.black24,
    onErrorContainer: CrystalColors.black,
    surface: CrystalColors.white,
    onSurface: CrystalColors.black,
    surfaceContainerHighest: CrystalColors.black12,
    onSurfaceVariant: CrystalColors.black60,
    outline: CrystalColors.black40,
    outlineVariant: CrystalColors.black12,
    shadow: CrystalColors.black,
    scrim: CrystalColors.black,
    inverseSurface: CrystalColors.black,
    onInverseSurface: CrystalColors.white,
    inversePrimary: CrystalColors.white,
    surfaceTint: CrystalColors.green,
  );

  static final _darkTokens = _MessengerTokens._(
    isDark: true,
    bubbleOutgoing: CrystalColors.green,
    bubbleIncoming: CrystalColors.black,
    bubbleBorder: CrystalColors.green24,
    onOutgoing: CrystalColors.black,
    onIncoming: CrystalColors.white,
    tray: CrystalColors.white12,
    divider: CrystalColors.white12,
  );

  static final _lightTokens = _MessengerTokens._(
    isDark: false,
    bubbleOutgoing: CrystalColors.green,
    bubbleIncoming: CrystalColors.white,
    bubbleBorder: CrystalColors.green24,
    onOutgoing: CrystalColors.black,
    onIncoming: CrystalColors.black,
    tray: CrystalColors.black12,
    divider: CrystalColors.black12,
  );

  static ThemeData _base(ColorScheme scheme, _MessengerTokens tokens) {
    final isDark = scheme.brightness == Brightness.dark;
    final surface = scheme.surface;
    final onSurface = scheme.onSurface;

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      // One transition for the whole app.
      //
      // go_router builds a MaterialPage for every route, which resolves its
      // animation through this theme - so setting it here covers every screen
      // without touching a single route definition. Previously each platform
      // used its own default, meaning the same navigation slid on iOS and
      // faded on Android.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CrystalPageTransition(),
          TargetPlatform.iOS: CrystalPageTransition(),
          TargetPlatform.macOS: CrystalPageTransition(),
          TargetPlatform.windows: CrystalPageTransition(),
          TargetPlatform.linux: CrystalPageTransition(),
          TargetPlatform.fuchsia: CrystalPageTransition(),
        },
      ),
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      // Inter via google_fonts — no font asset files required.
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: scheme.brightness).textTheme,
      ),
      iconTheme: IconThemeData(
        color: isDark ? CrystalColors.white : CrystalColors.black,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.tray,
        prefixIconColor: scheme.outline,
        hintStyle: TextStyle(color: scheme.outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CrystalColors.green, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        textColor: onSurface,
        subtitleTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.outline),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(color: surface, elevation: 8),
      dividerTheme: DividerThemeData(color: tokens.divider),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.primary,
        contentTextStyle: TextStyle(color: scheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        hourMinuteTextColor: onSurface,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? CrystalColors.green
              : CrystalColors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? CrystalColors.green24
              : CrystalColors.white24,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: isDark
            ? CrystalColors.white24
            : CrystalColors.black24,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.tray,
        selectedColor: CrystalColors.green24,
        labelStyle: TextStyle(color: onSurface),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

/// Messenger-specific tokens that are shared across pages/widgets so the
/// bubble geometry, trays and dividers stay visually consistent.
class _MessengerTokens {
  const _MessengerTokens._({
    required this.isDark,
    required this.bubbleOutgoing,
    required this.bubbleIncoming,
    required this.bubbleBorder,
    required this.onOutgoing,
    required this.onIncoming,
    required this.tray,
    required this.divider,
  });

  final bool isDark;
  final Color bubbleOutgoing;
  final Color bubbleIncoming;
  final Color bubbleBorder;
  final Color onOutgoing;
  final Color onIncoming;
  final Color tray;
  final Color divider;
}

/// Read-only access to the palette for widgets that paint outside the theme
/// (avataars, presence dots, bubbles).
extension MessengerTheme on BuildContext {
  Color get outgoingBubble => Theme.of(this).brightness == Brightness.dark
      ? CrystalColors.green
      : CrystalColors.green;

  Color get incomingBubble =>
      Theme.of(this).colorScheme.surfaceContainerHighest;

  Color get onBubbleIncoming => Theme.of(this).colorScheme.onSurface;
}

/// The app's page transition, shared by every route on every platform.
///
/// A scale-and-fade rather than a slide. Slides read well in a single
/// direction but fight the tab bar at the bottom of this app: a horizontally
/// sliding page implies lateral navigation, while every destination here is
/// "deeper" than where it was opened from. Scaling from 96% and fading in keeps
/// the outgoing page present underneath, which suits the glass surfaces - they
/// read as stacked panes rather than replaced pages.
///
/// Starting at 0.96 rather than 0 matters: a full scale-from-zero makes text
/// briefly blurry and looks like a zoom effect rather than a transition.
class CrystalPageTransition extends PageTransitionsBuilder {
  const CrystalPageTransition();

  /// Duration is supplied by the [PageRoute] itself (`MaterialPage` uses the
  /// framework default of 200 ms), not by this builder, so it is not repeated
  /// here as a constant that would silently disagree with the route.

  /// Screens that slide sideways instead of scaling: horizontally swipeable
  /// detail views such as the media viewer, where the direction of travel
  /// carries meaning.
  static const bool _isHorizontalSwipe = false;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

    return SlideTransition(
      position: Tween<Offset>(
        begin: _isHorizontalSwipe
            ? const Offset(0.12, 0)
            : const Offset(0, 0.035),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
