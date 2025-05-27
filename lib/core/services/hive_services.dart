import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:monetaze/core/models/goal_model.dart';

class HiveService {
  static const _themeBoxName = 'themeBox';
  static const _themeModeKey = 'themeMode';
  static const _themeIndexKey = 'themeIndex';
  static const _goalsBoxName = 'goals';

  static Future<void> init() async {
    await Hive.openBox<Goal>(_goalsBoxName);
    await Hive.openBox(_themeBoxName);
  }

  static Box<Goal> get goalsBox => Hive.box<Goal>(_goalsBoxName);

  static Box<Goal> get _goalsBox => Hive.box<Goal>(_goalsBoxName);

  static Box get _box => Hive.box(_themeBoxName);

  // Goal CRUD Operations
  static Future<void> addGoal(Goal goal) async {
    await goalsBox.put(goal.id, goal);
  }

  static Future<void> updateGoal(Goal goal) async {
    await goalsBox.put(goal.id, goal);
  }

  static Future<void> deleteGoal(String goalId) async {
    await goalsBox.delete(goalId);
  }

  static List<Goal> getAllGoals() {
    return goalsBox.values.toList();
  }

  static Future<void> clearAllGoals() async {
    await goalsBox.clear();
  }

  // Save theme data
  static Future<void> saveTheme(ThemeMode mode, int index) async {
    await _box.putAll({
      _themeModeKey: mode.index, // Convert enum to int
      _themeIndexKey: index,
    });
  }

  static (ThemeMode, int) loadTheme() {
    try {
      return (
        ThemeMode.values[_box.get(
          _themeModeKey,
          defaultValue: ThemeMode.system.index,
        )],
        _box.get(_themeIndexKey, defaultValue: 0),
      );
    } catch (e) {
      return (ThemeMode.system, 0); // Fallback values
    }
  }
}
