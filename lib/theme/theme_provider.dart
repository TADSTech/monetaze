import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:monetaze/core/models/user_model.dart';
import 'package:monetaze/core/services/hive_services.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode;
  int _themeIndex;
  User? _user;

  ThemeProvider({User? user})
    : _user = user,
      _themeMode = user?.themeMode ?? ThemeMode.system,
      _themeIndex = user?.themeIndex ?? 0 {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      if (_user == null) {
        final (mode, index) = await HiveService.loadTheme();
        _themeMode = mode;
        _themeIndex = index;
      } else {
        _themeMode = _user!.themeMode;
        _themeIndex = _user!.themeIndex;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
      // Fallback to default values
      _themeMode = ThemeMode.system;
      _themeIndex = 0;
      notifyListeners();
      rethrow;
    }
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
    FlexScheme.wasabi,
    FlexScheme.gold,
    FlexScheme.aquaBlue,
  ];

  ThemeMode get themeMode => _themeMode;
  int get themeIndex => _themeIndex;
  List<FlexScheme> get availableThemes => _availableThemes;
  FlexScheme get currentScheme => _availableThemes[_themeIndex];

  ThemeData getLightTheme() {
    return FlexThemeData.light(
      scheme: _availableThemes[_themeIndex],
      surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
      blendLevel: 20,
      appBarOpacity: 0.95,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        blendOnColors: false,
        inputDecoratorBorderType: FlexInputBorderType.underline,
        inputDecoratorRadius: 8.0,
        chipRadius: 8.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
    );
  }

  ThemeData getDarkTheme() {
    return FlexThemeData.dark(
      scheme: _availableThemes[_themeIndex],
      surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
      blendLevel: 15,
      appBarOpacity: 0.90,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 30,
        blendOnColors: false,
        inputDecoratorBorderType: FlexInputBorderType.underline,
        inputDecoratorRadius: 8.0,
        chipRadius: 8.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
    );
  }

  Color get navBarColor =>
      _themeMode == ThemeMode.dark ? Colors.grey.shade900 : Colors.white;

  Color get navBarSelectedColor =>
      _themeMode == ThemeMode.dark ? Colors.white : FlexColor.moneyLightPrimary;

  Color get navBarUnselectedColor =>
      _themeMode == ThemeMode.dark
          ? Colors.grey.shade400
          : Colors.grey.shade600;

  // Updated theme control methods
  void toggleThemeMode() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _updateUserTheme(); // Call to update user preferences
    notifyListeners();
  }

  void nextTheme() {
    if (_availableThemes.isEmpty) return;
    final newIndex = _themeIndex + 1;
    _themeIndex = newIndex >= _availableThemes.length ? 0 : newIndex;
    _updateUserTheme(); // Call to update user preferences
    notifyListeners();
  }

  void setTheme(int index) {
    _themeIndex = index % _availableThemes.length;
    _updateUserTheme(); // Call to update user preferences
    notifyListeners();
  }

  void _updateUserTheme() {
    if (_user != null) {
      HiveService.updateUserThemePreferences(_themeMode, _themeIndex);
    } else {
      HiveService.saveTheme(_themeMode, _themeIndex);
    }
  }

  void setUser(User? user) {
    _user = user;
    if (user != null) {
      _themeMode = user.themeMode;
      _themeIndex = user.themeIndex;
    }
    _loadSavedTheme();
    notifyListeners();
  }
}
