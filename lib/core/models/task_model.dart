import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 6)
class Task {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String goalId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final DateTime dueDate;

  @HiveField(4)
  final double amount;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  final String currency;

  Task({
    required this.id,
    required this.goalId,
    required this.title,
    required this.dueDate,
    required this.amount,
    this.isCompleted = false,
    this.currency = '₦',
  });
}
