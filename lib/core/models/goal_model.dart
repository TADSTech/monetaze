import 'package:hive/hive.dart';

part 'goal_model.g.dart';

@HiveType(typeId: 5)
enum SavingsInterval {
  @HiveField(0)
  daily,

  @HiveField(1)
  weekly,

  @HiveField(2)
  monthly,

  @HiveField(3)
  yearly,
}

@HiveType(typeId: 0)
class Goal {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double targetAmount;

  @HiveField(3)
  double currentAmount;

  @HiveField(4)
  final String currency;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  DateTime? targetDate;

  @HiveField(7)
  String? category;

  @HiveField(8)
  String? description;

  @HiveField(9)
  bool isCompleted;

  @HiveField(10)
  final SavingsInterval savingsInterval;

  @HiveField(11)
  final double startingAmount;

  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currency = '₦',
    this.currentAmount = 0,
    this.targetDate,
    this.category,
    this.description,
    this.isCompleted = false,
    this.savingsInterval = SavingsInterval.monthly,
    this.startingAmount = 0,
  }) : createdAt = DateTime.now() {
    currentAmount += startingAmount;
  }

  double get progress => targetAmount > 0 ? currentAmount / targetAmount : 0;

  // Calculate required periodic payment
  double get requiredPeriodicPayment {
    if (targetDate == null) return 0;

    final now = DateTime.now();
    final remainingDays = targetDate!.difference(now).inDays;
    if (remainingDays <= 0) return 0;

    switch (savingsInterval) {
      case SavingsInterval.daily:
        return (targetAmount - currentAmount) / remainingDays;
      case SavingsInterval.weekly:
        return (targetAmount - currentAmount) / (remainingDays / 7);
      case SavingsInterval.monthly:
        return (targetAmount - currentAmount) / (remainingDays / 30);
      case SavingsInterval.yearly:
        return (targetAmount - currentAmount) / (remainingDays / 365);
    }
  }

  // Get interval description
  String get intervalDescription {
    switch (savingsInterval) {
      case SavingsInterval.daily:
        return 'Daily';
      case SavingsInterval.weekly:
        return 'Weekly';
      case SavingsInterval.monthly:
        return 'Monthly';
      case SavingsInterval.yearly:
        return 'Yearly';
    }
  }

  // Get days remaining
  int? get daysRemaining {
    if (targetDate == null) return null;
    final remaining = targetDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }
}
