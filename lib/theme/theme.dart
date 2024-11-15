import 'package:flutter/material.dart';

ThemeData defaultTheme() {
  return ThemeData(
    useMaterial3: true,
    primarySwatch: Colors.deepPurple,
    scaffoldBackgroundColor: const Color(0xFF121212),
    focusColor: Colors.black.withOpacity(0.6),
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.deepPurple,
      accentColor: Colors.orangeAccent,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: Colors.orangeAccent, // Vibrant accent color
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20, // Increased from 16
        color: Colors.white70,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18, // Increased from 14
        color: Colors.white,
      ),
      headlineSmall: TextStyle(
        fontSize: 28.0, // Increased from 24
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey, width: 2), // Thicker border
      ),
      focusedBorder: OutlineInputBorder(
        borderSide:
            BorderSide(color: Colors.deepPurple, width: 2), // Thicker border
      ),
      labelStyle: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: 20, // Increased font size
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.deepPurple,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20, // Increased font size
        ),
        padding: const EdgeInsets.symmetric(
            vertical: 16, horizontal: 32), // Increased padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // More rounded
        ),
        elevation: 8, // Increased elevation for shadow effect
        shadowColor: Colors.deepPurpleAccent, // Shadow color
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.deepPurple,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.deepPurple,
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: 18, // Increased font size
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // More rounded
      ),
      elevation: 6,
      actionTextColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 24.0, vertical: 12.0), // Increased padding
      actionBackgroundColor: Colors.deepOrange,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: Colors.white,
    ),
    dividerTheme: const DividerThemeData(
      color: Colors.grey,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.all(Colors.deepPurple),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.all(Colors.deepPurple),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.deepPurple),
      trackColor: WidgetStateProperty.all(Colors.grey.shade300),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: Colors.deepPurple,
      ),
      textStyle: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.deepPurple.withOpacity(0.2),
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.deepPurple,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Colors.black,
    ),
    cardTheme: const CardTheme(
      color: Colors.white,
      elevation: 2,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey,
    ),
    bottomAppBarTheme: const BottomAppBarTheme(
      color: Colors.white,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      CustomColors(
        gradientStart: Colors.pinkAccent, // Changed to a more vibrant color
        gradientEnd: Colors.deepPurpleAccent,
        buttonBackground: Colors.deepPurple, // Defined
        buttonForeground: Colors.white,
        focusBorder: Colors.orangeAccent, // Changed for better visibility
        dialogBackground: Colors.white, // Added
        dialogTitleColor: Colors.black, // Added
        dialogTextColor: Colors.black87, // Added
        buttonTextColor: Colors.white, // Added
      ),
    ],
  );
}

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  final Color gradientStart;
  final Color gradientEnd;
  final Color buttonBackground; // Added
  final Color buttonForeground; // Added
  final Color focusBorder;
  final Color dialogBackground; // Added
  final Color dialogTitleColor; // Added
  final Color dialogTextColor; // Added
  final Color buttonTextColor; // Added

  const CustomColors({
    required this.gradientStart,
    required this.gradientEnd,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.focusBorder,
    required this.dialogBackground, // Added
    required this.dialogTitleColor, // Added
    required this.dialogTextColor, // Added
    required this.buttonTextColor, // Added
  }); // Fixed closing parenthesis and brace

  @override
  CustomColors copyWith({
    Color? gradientStart,
    Color? gradientEnd,
    Color? buttonBackground,
    Color? buttonForeground,
    Color? focusBorder,
    Color? dialogBackground, // Added
    Color? dialogTitleColor, // Added
    Color? dialogTextColor, // Added
    Color? buttonTextColor, // Added
  }) {
    return CustomColors(
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      buttonBackground: buttonBackground ?? this.buttonBackground,
      buttonForeground: buttonForeground ?? this.buttonForeground,
      focusBorder: focusBorder ?? this.focusBorder,
      dialogBackground: dialogBackground ?? this.dialogBackground, // Added
      dialogTitleColor: dialogTitleColor ?? this.dialogTitleColor, // Added
      dialogTextColor: dialogTextColor ?? this.dialogTextColor, // Added
      buttonTextColor: buttonTextColor ?? this.buttonTextColor, // Added
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      buttonBackground:
          Color.lerp(buttonBackground, other.buttonBackground, t)!,
      buttonForeground:
          Color.lerp(buttonForeground, other.buttonForeground, t)!,
      focusBorder: Color.lerp(focusBorder, other.focusBorder, t)!,
      dialogBackground:
          Color.lerp(dialogBackground, other.dialogBackground, t)!, // Added
      dialogTitleColor:
          Color.lerp(dialogTitleColor, other.dialogTitleColor, t)!, // Added
      dialogTextColor:
          Color.lerp(dialogTextColor, other.dialogTextColor, t)!, // Added
      buttonTextColor:
          Color.lerp(buttonTextColor, other.buttonTextColor, t)!, // Added
    );
  }
}
