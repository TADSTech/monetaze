import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:monetaze/core/services/notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/task_model.dart';

class TaskService {
  static final Uuid _uuid = const Uuid();

  static Future<void> generateTasksForGoal(Goal goal) async {
    try {
      final tasksBox = await Hive.openBox<Task>('tasks');
      final now = DateTime.now();

      // Get all existing tasks for this goal
      final existingTasks =
          tasksBox.values.where((t) => t.goalId == goal.id).toList();

      // Separate completed and incomplete tasks
      final completedTasks = existingTasks.where((t) => t.isCompleted).toList();
      final incompleteTasks =
          existingTasks.where((t) => !t.isCompleted).toList();

      // Clear only incomplete tasks that are in the future
      await Future.wait(
        incompleteTasks
            .where((t) => t.dueDate.isAfter(now))
            .map((t) => tasksBox.delete(t.id)),
      );

      // Don't regenerate if goal is completed
      if (goal.isCompleted) return;

      // Calculate total duration from start to target date (moved outside if block)
      final totalDuration = goal.targetDate?.difference(goal.startDate);

      // If no target date, create just one task due today
      if (goal.targetDate == null) {
        // Check if we already have a task for today
        final hasTaskForToday = existingTasks.any(
          (t) =>
              t.dueDate.year == now.year &&
              t.dueDate.month == now.month &&
              t.dueDate.day == now.day,
        );

        if (!hasTaskForToday) {
          final task = Task(
            id: _uuid.v4(),
            goalId: goal.id,
            title: 'Payment for ${goal.name}',
            dueDate: now,
            amount:
                goal.originalPeriodicPayment, // Changed from requiredPeriodicPayment
            currency: goal.currency,
          );
          await tasksBox.put(task.id, task);
        }
        return;
      }

      // Generate tasks based on interval
      switch (goal.savingsInterval) {
        case SavingsInterval.daily:
          final days = totalDuration!.inDays; // Use totalDuration here
          for (var i = 0; i <= days; i++) {
            final dueDate = goal.startDate.add(Duration(days: i));
            if (dueDate.isAfter(goal.targetDate!)) continue;

            // Skip if we already have a task for this date
            if (existingTasks.any(
              (t) =>
                  t.dueDate.year == dueDate.year &&
                  t.dueDate.month == dueDate.month &&
                  t.dueDate.day == dueDate.day,
            ))
              continue;

            final task = Task(
              id: _uuid.v4(),
              goalId: goal.id,
              title: 'Daily payment for ${goal.name}',
              dueDate: dueDate,
              amount:
                  goal.originalPeriodicPayment, // Changed from requiredPeriodicPayment
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);

            if (dueDate.isAfter(now)) {
              await NotificationService().scheduleTaskNotification(task, goal);
            }
          }
          break;

        case SavingsInterval.weekly:
          final weeks =
              (totalDuration!.inDays / 7).ceil(); // Use totalDuration here
          for (var i = 0; i <= weeks; i++) {
            final dueDate = goal.startDate.add(Duration(days: i * 7));
            if (dueDate.isAfter(goal.targetDate!)) continue;

            // Skip if we already have a task for this week
            if (existingTasks.any((t) => _isSameWeek(t.dueDate, dueDate)))
              continue;

            final task = Task(
              id: _uuid.v4(),
              goalId: goal.id,
              title: 'Weekly payment for ${goal.name}',
              dueDate: dueDate,
              amount:
                  goal.originalPeriodicPayment, // Changed from requiredPeriodicPayment
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);

            if (dueDate.isAfter(now)) {
              await NotificationService().scheduleTaskNotification(task, goal);
            }
          }
          break;

        case SavingsInterval.monthly:
          final months =
              (totalDuration!.inDays / 30).ceil(); // Use totalDuration here
          for (var i = 0; i <= months; i++) {
            final dueDate = DateTime(
              goal.startDate.year,
              goal.startDate.month + i + 1,
              1, // First day of month
            );
            if (dueDate.isAfter(goal.targetDate!)) continue;

            // Skip if we already have a task for this month
            if (existingTasks.any(
              (t) =>
                  t.dueDate.year == dueDate.year &&
                  t.dueDate.month == dueDate.month,
            ))
              continue;

            final task = Task(
              id: _uuid.v4(),
              goalId: goal.id,
              title: 'Monthly payment for ${goal.name}',
              dueDate: dueDate,
              amount:
                  goal.originalPeriodicPayment, // Changed from requiredPeriodicPayment
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);

            if (dueDate.isAfter(now)) {
              await NotificationService().scheduleTaskNotification(task, goal);
            }
          }
          break;

        case SavingsInterval.yearly:
          final years =
              (totalDuration!.inDays / 365).ceil(); // Use totalDuration here
          for (var i = 0; i <= years; i++) {
            final dueDate = DateTime(
              goal.startDate.year + i + 1,
              1, // January
              1, // First day
            );
            if (dueDate.isAfter(goal.targetDate!)) continue;

            // Skip if we already have a task for this year
            if (existingTasks.any((t) => t.dueDate.year == dueDate.year))
              continue;

            final task = Task(
              id: _uuid.v4(),
              goalId: goal.id,
              title: 'Yearly payment for ${goal.name}',
              dueDate: dueDate,
              amount:
                  goal.originalPeriodicPayment, // Changed from requiredPeriodicPayment
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);

            if (dueDate.isAfter(now)) {
              await NotificationService().scheduleTaskNotification(task, goal);
            }
          }
          break;
      }
    } catch (e) {
      debugPrint('Error generating tasks for goal: $e');
      rethrow;
    }
  }

  // Helper function to check if two dates are in the same week
  static bool _isSameWeek(DateTime a, DateTime b) {
    final aStart = a.subtract(Duration(days: a.weekday - 1));
    final bStart = b.subtract(Duration(days: b.weekday - 1));
    return aStart.year == bStart.year &&
        aStart.month == bStart.month &&
        aStart.day == bStart.day;
  }

  static Future<void> updateTaskStatus(Task task) async {
    try {
      final tasksBox = await Hive.openBox<Task>('tasks');
      await tasksBox.put(task.id, task);
      debugPrint('Task ${task.id} status updated to ${task.isCompleted}');
    } catch (e) {
      debugPrint('Error updating task status: $e');
      rethrow;
    }
  }

  static Future<void> completeTask(Task task, double amount) async {
    try {
      final tasksBox = await Hive.openBox<Task>('tasks');
      final goalsBox = await Hive.openBox<Goal>('goals');

      // Update task status
      final updatedTask = task.copyWith(isCompleted: true);
      await tasksBox.put(updatedTask.id, updatedTask);

      // Update goal funding
      final goal = goalsBox.get(task.goalId);
      if (goal != null) {
        final newCurrentAmount = goal.currentAmount + amount;
        await goalsBox.put(
          goal.id,
          goal.copyWith(
            currentAmount: newCurrentAmount,
            isCompleted: newCurrentAmount >= goal.targetAmount,
          ),
        );
      }

      // Cancel any pending notification for this task
      await NotificationService().cancelNotification(task);
    } catch (e) {
      debugPrint('Error completing task: $e');
      rethrow;
    }
  }

  static Future<void> regenerateAllTasks() async {
    final goalsBox = await Hive.openBox<Goal>('goals');
    for (final goal in goalsBox.values) {
      // Only regenerate tasks for active goals
      if (!goal.isCompleted) {
        await generateTasksForGoal(goal);
      }
    }
  }
}
