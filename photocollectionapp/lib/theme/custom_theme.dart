import 'package:flutter/material.dart';

/// Centralised visual styling for the app.
/// This is the single place where those values are defined.
/// Widget code should never set colors, fonts, or sizes directly.
/// They should read them from `Theme.of(context)`.

class CustomTheme {
  CustomTheme._(); // Static-only container; not instantiable.

  // ---------------------------------------------------------------------
  // Brand colors
  // ---------------------------------------------------------------------

  static const Color _barLight = Color.fromRGBO(0x50, 0x90, 0xd0, 1.0);
  static const Color _barDark = Color.fromRGBO(0x30, 0x60, 0xb0, 1.0);

  // ---------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------

  static const String _fontFamily = 'Ubuntu';

  /// Tweak the text size of popup menu items by a scale factor.
  static const double _popupMenuFontScale = 1.25;

  /// Material 3's documented bodyLarge size (m3.material.io/styles/typography/tokens).
  /// Defined explicitly because Flutter only resolves this value from
  /// locale-dependent geometry inside the widget tree — it's null on
  /// any ThemeData built outside of build(), so it can't be read back
  /// off a constructed ThemeData at this point in the code.
  static const double _bodyLargeSize = 16.0;

  /*
  static TextTheme _buildTextTheme(Brightness brightness) {
    final typography = Typography.material2021();
    final base = brightness == Brightness.light 
      ? typography.black 
      : typography.white;
    final textColor = brightness == Brightness.light 
      ? Colors.black 
      : Colors.white;
    return base.apply(
      fontFamily: _fontFamily,
      bodyColor: textColor,
      displayColor: textColor,
    );
  }
  */

  // ---------------------------------------------------------------------
  // Component themes
  // ---------------------------------------------------------------------

  static const BottomNavigationBarThemeData _bottomNavigationBarTheme =
      BottomNavigationBarThemeData(
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        showUnselectedLabels: true,
        showSelectedLabels: true,
        type: BottomNavigationBarType.fixed,
      );

  static PopupMenuThemeData _popupMenuTheme(Color textColor) {
    return PopupMenuThemeData(
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: _fontFamily,
          fontSize: _bodyLargeSize * _popupMenuFontScale,
          color: textColor,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Theme assembly
  // ---------------------------------------------------------------------

  static ThemeData _buildTheme(Brightness brightness) {
    final seed = brightness == Brightness.light ? _barLight : _barDark;
    final textColor =
        brightness == Brightness.light ? Colors.black : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: seed,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: textColor,
      ),
      bottomNavigationBarTheme: _bottomNavigationBarTheme.copyWith(
        backgroundColor: seed,
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            fontFamily: _fontFamily,
            bodyColor: textColor,
            displayColor: textColor,
          ),
      popupMenuTheme: _popupMenuTheme(textColor),
      iconTheme: IconThemeData(color: textColor),
    );
  }

  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);
}
