import 'package:flutter/material.dart';

ThemeData darkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: Color(0xFF1D2A44), // Dark blue for app bars, buttons
    scaffoldBackgroundColor: Color.fromARGB(233, 18, 18, 18), // Main background
    cardColor: Color(0xFF1E2A3C), // Surface for panels, cards
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF1D2A44),
      secondary: Color(0xFF3B5998),
      surface: Color(0xFF1E2A3C),
      background: Color(0xFF121212),
      error: Color(0xFFFF5555),
      onPrimary: Color(0xFFE7ECEF), // Text/icon on primary
      onSecondary: Color(0xFFE7ECEF), // Text/icon on secondary
      onSurface: Color(0xFFE7ECEF), // Text/icon on surfaces
      onBackground: Color(0xFFE7ECEF), // Text/icon on background
      onError: Color(0xFF121212), // Text/icon on error
    ),
    hintColor: Color(0xFF00D4B9), // Teal for interactive elements
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFE7ECEF)), // Primary text
      bodyMedium: TextStyle(color: Color(0xFFA0AEC0)), // Secondary text
      bodySmall: TextStyle(color: Color(0xFFE7ECEF)), // Button text
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Color(0xFF3B5998), // Secondary blue for buttons
      textTheme: ButtonTextTheme.primary,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Color(0xFFE7ECEF), // Text/icon on buttons
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF3B5998), // Secondary blue
        foregroundColor: Color(0xFFE7ECEF), // Text/icon on buttons
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Color(0xFF00D4B9), // Teal for active slider
      inactiveTrackColor: Color(0xFF1E2A3C), // Surface for inactive
      thumbColor: Color(0xFF00D4B9), // Teal thumb
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF1D2A44), // Dark blue app bar
      foregroundColor: Color(0xFFE7ECEF), // Text/icons on app bar
    ),
  );
}
