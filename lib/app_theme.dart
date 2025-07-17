import 'package:flutter/material.dart';

const primaryColor = Color(0xFF0A84FF);
const secondaryColor = Color(0xFF7B61FF);
const lightBgColor = Color(0xFFF6F6F6);
const darkBgColor = Color(0xFF181A20);
const lightCardColor = Colors.white;
const darkCardColor = Color(0xFF23272F);

const lightNeumorphShadow = Color(0xFFD1D9E6);
const lightNeumorphHighlight = Colors.white;
const darkNeumorphShadow = Color(0xFF111215);
const darkNeumorphHighlight = Color(0xFF23272F);
const glassLightColor = Colors.white;
const glassDarkColor = Color(0xFF23272F);
final ThemeData customLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: lightBgColor,
  cardColor: lightCardColor,
  primaryColor: primaryColor,
  colorScheme: ColorScheme.light(
    primary: primaryColor,
    secondary: secondaryColor,
    background: lightBgColor,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onBackground: Colors.black,
    surface: Colors.white,
    onSurface: Colors.black87,
    error: Colors.red,
    onError: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      color: Colors.black87,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(color: Colors.black87, fontSize: 16),
    bodyLarge: TextStyle(color: Colors.black87, fontSize: 18),
    labelLarge: TextStyle(color: primaryColor),
  ),
  iconTheme: const IconThemeData(color: Colors.black87),
  dividerColor: Colors.black12,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    labelStyle: const TextStyle(color: Colors.black45),
    hintStyle: const TextStyle(color: Colors.black38),
    prefixIconColor: Colors.black54,
  ),
);

final ThemeData customDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: darkBgColor,
  cardColor: darkCardColor,
  primaryColor: primaryColor,
  colorScheme: ColorScheme.dark(
    primary: primaryColor,
    secondary: secondaryColor,
    background: darkBgColor,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    onBackground: Colors.white,
    surface: darkCardColor,
    onSurface: Colors.white70,
    error: Colors.red,
    onError: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(color: Colors.white70, fontSize: 16),
    bodyLarge: TextStyle(color: Colors.white, fontSize: 18),
    labelLarge: TextStyle(color: primaryColor),
  ),
  iconTheme: const IconThemeData(color: Colors.white70),
  dividerColor: Colors.white12,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: darkCardColor.withOpacity(0.8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    labelStyle: const TextStyle(color: Colors.white54),
    hintStyle: const TextStyle(color: Colors.white38),
    prefixIconColor: Colors.white54,
  ),
);
