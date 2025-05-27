import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:monetaze/core/services/hive_services.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int _themeIndex = 0;

  ThemeProvider() {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final (mode, index) = HiveService.loadTheme();
    _themeMode = mode;
    _themeIndex = index;
    notifyListeners();
  }

  final List<FlexScheme> _availableThemes = [
    FlexScheme.money,
    FlexScheme.deepPurple,
    FlexScheme.espresso,
    FlexScheme.outerSpace,
    FlexScheme.hippieBlue,
    FlexScheme.flutterDash,
    FlexScheme.sakura,
    FlexScheme.red,
    FlexScheme.green,
    FlexScheme.blue,
    FlexScheme.gold,
    FlexScheme.mandyRed,
  ]..removeWhere((x) => x == null);

  FlexScheme get currentScheme {
    if (_availableThemes.isEmpty) return FlexScheme.money;
    return _availableThemes[_themeIndex % _availableThemes.length];
  }

  // Custom navigation bar colors for each theme (light/dark variants)
  final List<Color> _navBarLightColors = [
    Colors.blueGrey.shade100, // Money
    Colors.deepPurple.shade100, // Deep Purple
    Colors.brown.shade100, // Espresso
  ];

  final List<Color> _navBarDarkColors = [
    Colors.blueGrey.shade800, // Money
    Colors.deepPurple.shade800, // Deep Purple
    Colors.brown.shade800, // Espresso
  ];

  // Getters
  ThemeMode get themeMode => _themeMode;
  int get themeIndex => _themeIndex;
  List<FlexScheme> get availableThemes => _availableThemes;

  Color get navBarColor =>
      _themeMode == ThemeMode.dark
          ? _navBarDarkColors[_themeIndex]
          : _navBarLightColors[_themeIndex];

  Color get navBarSelectedColor =>
      _themeMode == ThemeMode.dark ? Colors.white : FlexColor.moneyLightPrimary;

  Color get navBarUnselectedColor =>
      _themeMode == ThemeMode.dark
          ? Colors.grey.shade400
          : Colors.grey.shade600;

  // Theme control methods
  void toggleThemeMode() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void nextTheme() {
    if (_availableThemes.isEmpty) return;
    final newIndex = _themeIndex + 1;
    _themeIndex = newIndex >= _availableThemes.length ? 0 : newIndex;
    notifyListeners();
  }

  void setTheme(int index) {
    _themeIndex = index % _availableThemes.length;
    notifyListeners();
  }

  ThemeData getLightTheme() => FlexThemeData.light(
    scheme: currentScheme,
    appBarStyle: FlexAppBarStyle.primary,
  );

  ThemeData getDarkTheme() => FlexThemeData.dark(
    scheme: currentScheme,
    appBarStyle: FlexAppBarStyle.primary,
  );
}
