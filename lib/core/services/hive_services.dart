import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/quote_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:monetaze/core/models/user_model.dart';

class HiveService {
  static const _themeBoxName = 'themeBox';
  static const _themeModeKey = 'themeMode';
  static const _themeIndexKey = 'themeIndex';
  static const _goalsBoxName = 'goals';
  static const _tasksBoxName = 'tasks';
  static const _userBoxName = 'user';
  static const _quotesBoxName = 'quotes';

  static Future<void> init() async {
    try {
      // Open all boxes with error handling
      await Future.wait([
        _openBox<Goal>(_goalsBoxName),
        _openBox<Task>(_tasksBoxName),
        _openBox<User>(_userBoxName),
        _openBox(_themeBoxName),
        _openBox<MotivationalQuote>(_quotesBoxName),
      ]);
      debugPrint('All Hive boxes initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Hive boxes: $e');
      rethrow;
    }
  }

  static Future<Box<T>> _openBox<T>(String name) async {
    try {
      if (!Hive.isBoxOpen(name)) {
        return await Hive.openBox<T>(name);
      }
      return Hive.box<T>(name);
    } catch (e) {
      debugPrint('Error opening box $name: $e');
      rethrow;
    }
  }

  // Box getters
  static Box<Goal> get goalsBox => Hive.box<Goal>(_goalsBoxName);
  static Box<Task> get tasksBox => Hive.box<Task>(_tasksBoxName);
  static Box<User> get userBox => Hive.box<User>(_userBoxName);
  static Box get themeBox => Hive.box(_themeBoxName);
  static Box<MotivationalQuote> get quotesBox =>
      Hive.box<MotivationalQuote>(_quotesBoxName);

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

  static Goal? getGoal(String goalId) {
    return goalsBox.get(goalId);
  }

  static Future<void> clearAllGoals() async {
    await goalsBox.clear();
  }

  // Goal Funding Operations
  static Future<void> fundGoal(String goalId, double amount) async {
    final goal = goalsBox.get(goalId);
    if (goal != null) {
      final newCurrentAmount = goal.currentAmount + amount;
      final updatedGoal = goal.copyWith(
        currentAmount: newCurrentAmount,
        isCompleted: newCurrentAmount >= goal.targetAmount,
      );
      await goalsBox.put(updatedGoal.id, updatedGoal);
      debugPrint(
        'Goal ${goal.name} funded with $amount. New amount: $newCurrentAmount',
      );
    }
  }

  // Goal Completion Operations
  static Future<void> markGoalAsCompleted(
    String goalId, [
    bool? isCompleted,
  ]) async {
    final goal = goalsBox.get(goalId);
    if (goal != null) {
      final updatedGoal = goal.copyWith(
        currentAmount:
            isCompleted == false ? goal.currentAmount : goal.targetAmount,
        isCompleted: isCompleted ?? true,
      );
      await goalsBox.put(updatedGoal.id, updatedGoal);
      debugPrint(
        'Goal ${goal.name} marked as ${isCompleted ?? true ? 'complete' : 'incomplete'}.',
      );
    }
  }

  // Goal Progress Operations
  static double getGoalProgress(String goalId) {
    final goal = goalsBox.get(goalId);
    return goal?.progress ?? 0;
  }

  // Goal Filtering Operations
  static List<Goal> getCompletedGoals() {
    return goalsBox.values.where((goal) => goal.isCompleted).toList();
  }

  static List<Goal> getActiveGoals() {
    return goalsBox.values.where((goal) => !goal.isCompleted).toList();
  }

  // Task Operations
  static Future<List<Task>> getTasksForGoal(String goalId) async {
    return tasksBox.values.where((task) => task.goalId == goalId).toList();
  }

  static Future<List<Task>> getCompletedTasks() async {
    return tasksBox.values.where((task) => task.isCompleted).toList();
  }

  static Future<List<Task>> getPendingTasks() async {
    final now = DateTime.now();
    return tasksBox.values
        .where((task) => !task.isCompleted && task.dueDate.isAfter(now))
        .toList();
  }

  static Future<List<Task>> getOverdueTasks() async {
    final now = DateTime.now();
    return tasksBox.values
        .where((task) => !task.isCompleted && task.dueDate.isBefore(now))
        .toList();
  }

  static (ThemeMode, int) loadTheme() {
    final themeModeIndex =
        themeBox.get(_themeModeKey, defaultValue: ThemeMode.system.index)
            as int;
    final themeIndex = themeBox.get(_themeIndexKey, defaultValue: 0) as int;
    return (ThemeMode.values[themeModeIndex], themeIndex);
  }

  static Future<void> saveTheme(ThemeMode mode, int index) async {
    await themeBox.put(_themeModeKey, mode.index);
    await themeBox.put(_themeIndexKey, index);
  }

  static Future<void> updateUserThemePreferences(
    ThemeMode mode,
    int index,
  ) async {
    User? user = await getCurrentUser();
    if (user != null) {
      // Create a new User object with updated theme preferences
      final updatedUser = user.copyWith(themeMode: mode, themeIndex: index);
      // Save the updated User object back to Hive
      await saveCurrentUser(updatedUser);
    } else {
      // If no user is logged in, save theme preferences directly to themeBox
      await saveTheme(mode, index);
    }
  }

  static Future<User?> getCurrentUser() async {
    return userBox.get('current_user');
  }

  static Future<void> saveCurrentUser(User user) async {
    try {
      // Ensure box is open
      final box = await _openBox<User>(_userBoxName);
      final themeBox = await _openBox(_themeBoxName);

      // Save user data
      await box.put('current_user', user);

      // Save theme preferences
      await themeBox.putAll({
        _themeModeKey: user.themeMode.index,
        _themeIndexKey: user.themeIndex,
      });

      // Force write to disk
      await box.flush();
      await themeBox.flush();

      debugPrint('User saved successfully: ${user.toString()}');
    } catch (e) {
      debugPrint('Error saving user: $e');
      rethrow;
    }
  }

  static Future<void> clearCurrentUser() async {
    await userBox.delete('current_user');
  }

  // Data synchronization
  static Future<void> syncAllData() async {
    try {
      await goalsBox.flush();
      await tasksBox.flush();
      await userBox.flush();
      await themeBox.flush();
    } catch (e) {
      debugPrint('Error syncing data: $e');
      rethrow;
    }
  }

  // Data validation
  static Future<bool> validateDataIntegrity() async {
    try {
      final invalidTasks =
          tasksBox.values.where((task) {
            return !goalsBox.containsKey(task.goalId);
          }).toList();

      if (invalidTasks.isNotEmpty) {
        debugPrint('Found ${invalidTasks.length} orphaned tasks');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Data validation error: $e');
      return false;
    }
  }
}
