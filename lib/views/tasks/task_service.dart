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

      if (goal.targetDate == null) {
        debugPrint('No target date set for goal ${goal.name}');
        return;
      }

      // Get existing completed tasks for this goal (only keep those before target date)
      final existingCompletedTasks =
          tasksBox.values
              .where(
                (t) =>
                    t.goalId == goal.id &&
                    t.isCompleted &&
                    t.dueDate.isBefore(goal.targetDate!),
              )
              .toList();

      // Clear only INCOMPLETE tasks for this goal
      final incompleteTasks =
          tasksBox.values
              .where((t) => t.goalId == goal.id && !t.isCompleted)
              .map((t) => t.id)
              .toList();
      await Future.wait(incompleteTasks.map((id) => tasksBox.delete(id)));

      // Calculate days remaining from now, not goal start date
      final daysRemaining = goal.targetDate!.difference(now).inDays;
      if (daysRemaining <= 0) {
        debugPrint('Goal ${goal.name} has already passed its target date');
        return;
      }

      // Calculate payment amount with safety checks
      final paymentAmount = goal.requiredPeriodicPayment;
      if (paymentAmount <= 0) {
        debugPrint('Invalid payment amount for goal ${goal.name}');
        return;
      }

      // Generate new tasks based on interval (only for non-completed dates)
      switch (goal.savingsInterval) {
        case SavingsInterval.daily:
          for (var i = 0; i < daysRemaining; i++) {
            final dueDate = now.add(Duration(days: i));
            if (existingCompletedTasks.any(
              (t) =>
                  t.dueDate.year == dueDate.year &&
                  t.dueDate.month == dueDate.month &&
                  t.dueDate.day == dueDate.day,
            )) {
              continue;
            }

            final task = Task(
              id: _uuid.v4(),
              goalId: goal.id,
              title: 'Daily payment for ${goal.name}',
              dueDate: dueDate,
              amount: paymentAmount,
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);

            // Only schedule notification if due date is in the future
            if (dueDate.isAfter(now)) {
              await NotificationService().scheduleTaskNotification(task, goal);
            }
          }
          break;

        case SavingsInterval.weekly:
          final weeks = (daysRemaining / 7).ceil();
          for (var i = 0; i < weeks; i++) {
            final dueDate = now.add(Duration(days: i * 7));
            if (existingCompletedTasks.any(
              (t) => _isSameWeek(t.dueDate, dueDate),
            )) {
              continue;
            }

            final task = Task(
              id: _uuid.v4(),
              goalId: goal.id,
              title: 'Weekly payment for ${goal.name}',
              dueDate: dueDate,
              amount: paymentAmount,
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);

            if (dueDate.isAfter(now)) {
              await NotificationService().scheduleTaskNotification(task, goal);
            }
          }
          break;

        case SavingsInterval.monthly:
          final months = (daysRemaining / 30).ceil();
          for (var i = 0; i < months; i++) {
            final dueDate = DateTime(now.year, now.month + i + 1, 1);
            if (existingCompletedTasks.any(
              (t) =>
                  t.dueDate.year == dueDate.year &&
                  t.dueDate.month == dueDate.month,
            )) {
              continue;
            }

            final task = Task(
              id: _uuid.v4(),
              goalId: goal.id,
              title: 'Monthly payment for ${goal.name}',
              dueDate: dueDate,
              amount: paymentAmount,
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);

            if (dueDate.isAfter(now)) {
              await NotificationService().scheduleTaskNotification(task, goal);
            }
          }
          break;

        case SavingsInterval.yearly:
          final years = (daysRemaining / 365).ceil();
          for (var i = 0; i < years; i++) {
            final dueDate = DateTime(now.year + i + 1, 1, 1);
            if (existingCompletedTasks.any(
              (t) => t.dueDate.year == dueDate.year,
            )) {
              continue;
            }

            final task = Task(
              id: _uuid.v4(),
              goalId: goal.id,
              title: 'Yearly payment for ${goal.name}',
              dueDate: dueDate,
              amount: paymentAmount,
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);

            if (dueDate.isAfter(now)) {
              await NotificationService().scheduleTaskNotification(task, goal);
            }
          }
          break;
      }

      debugPrint('Generated tasks for goal ${goal.name} successfully');
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

  static Future<void> regenerateAllTasks() async {
    final goalsBox = await Hive.openBox<Goal>('goals');
    for (final goal in goalsBox.values) {
      await generateTasksForGoal(goal);
    }
  }
}
