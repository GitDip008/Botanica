// lib/theme/app_theme.dart
//
// The Material theme, built from tokens.dart.
//
// Most screens use stock widgets — AppBar, TextField, FilledButton, dialogs,
// snackbars, sliders — and the old theme set almost none of them, so each fell
// back to Material defaults and then got hand-patched per screen. Theming them
// here restyles every screen at once, including the ones nobody has had time
// to rebuild, and means a new screen looks right without trying.

import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: C.accent,
    onPrimary: C.bg,
    secondary: C.gold,
    onSecondary: C.bg,
    surface: C.surface,
    onSurface: C.textHi,
    surfaceContainerHighest: C.surfaceAlt,
    error: C.danger,
    onError: C.bg,
    outline: C.line,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: R.rs,
    borderSide: BorderSide.none,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: C.line,
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1, space: 1),

    textTheme: const TextTheme(
      displaySmall: T.display,
      headlineSmall: T.h1,
      titleLarge: T.h1,
      titleMedium: T.h2,
      bodyLarge: T.body,
      bodyMedium: T.body,
      bodySmall: T.bodySm,
      labelLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      labelMedium: T.label,
    ),

    // Flat bars on the page colour, no hairline. The old bars sat on a
    // lighter strip with a rule under them — the heaviest thing on every
    // screen, and the least useful.
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: C.textHi,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: C.textSoft),
      titleTextStyle: TextStyle(
        color: C.textHi,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),

    // Filled inputs with no outline until focused.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      hintStyle: const TextStyle(color: C.textFaint),
      labelStyle: const TextStyle(color: C.textSoft),
      prefixIconColor: C.textSoft,
      suffixIconColor: C.textSoft,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Sp.l, vertical: 16),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: R.rs,
        borderSide: const BorderSide(color: C.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: R.rs,
        borderSide: const BorderSide(color: C.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: R.rs,
        borderSide: const BorderSide(color: C.danger, width: 1.5),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.accent,
        foregroundColor: C.bg,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: R.rs),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.accent,
        foregroundColor: C.bg,
        elevation: 0,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: R.rs),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.textHi,
        minimumSize: const Size(64, 50),
        side: const BorderSide(color: C.line, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: R.rs),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    cardTheme: CardThemeData(
      color: C.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: R.rm),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: R.rl),
      titleTextStyle: T.h2,
      contentTextStyle: T.bodySm,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: C.textFaint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.l)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.surfaceAlt,
      contentTextStyle: const TextStyle(color: C.textHi, fontSize: 14),
      actionTextColor: C.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: R.rs),
      elevation: 0,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: C.surface,
      selectedColor: C.accentWash,
      side: BorderSide.none,
      labelStyle: const TextStyle(color: C.text, fontSize: 13),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.pill)),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: C.accent,
      unselectedLabelColor: C.textFaint,
      indicatorColor: C.accent,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    ),

    sliderTheme: const SliderThemeData(
      activeTrackColor: C.accent,
      inactiveTrackColor: C.surfaceAlt,
      thumbColor: C.accent,
      overlayColor: C.accentWash,
      trackHeight: 5,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.bg : C.textSoft),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.accent : C.surfaceAlt),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: C.accent,
      linearTrackColor: C.surfaceAlt,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: C.accent,
      foregroundColor: C.bg,
      elevation: 0,
      highlightElevation: 0,
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: C.textSoft,
      textColor: C.textHi,
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
    ),

    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
