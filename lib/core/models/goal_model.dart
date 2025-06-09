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
  double currentAmount; // This is intentionally not final

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

  @HiveField(12)
  final DateTime startDate;

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
    DateTime? startDate,
    DateTime? createdAt,
  }) : startDate = startDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now() {
    if (currentAmount == 0 && startingAmount > 0) {
      currentAmount += startingAmount;
    }
  }

  double get progress => targetAmount > 0 ? currentAmount / targetAmount : 0;

  /// Calculates the payment amount based on the original schedule
  double get originalPeriodicPayment {
    if (targetDate == null)
      return targetAmount; // Single payment if no target date

    final totalDuration = targetDate!.difference(startDate);
    final totalDays = totalDuration.inDays;

    if (totalDays <= 0) return targetAmount;

    switch (savingsInterval) {
      case SavingsInterval.daily:
        return targetAmount / (totalDays > 0 ? totalDays : 1);
      case SavingsInterval.weekly:
        return targetAmount / (totalDays / 7 > 0 ? (totalDays / 7) : 1);
      case SavingsInterval.monthly:
        return targetAmount / (totalDays / 30 > 0 ? (totalDays / 30) : 1);
      case SavingsInterval.yearly:
        return targetAmount / (totalDays / 365 > 0 ? (totalDays / 365) : 1);
    }
  }

  /// Gets the due dates for all payments in the original schedule
  List<DateTime> getOriginalDueDates() {
    final dates = <DateTime>[];
    if (targetDate == null)
      return [DateTime.now()]; // Single payment if no target date

    final totalDuration = targetDate!.difference(startDate);

    switch (savingsInterval) {
      case SavingsInterval.daily:
        final days = totalDuration.inDays;
        for (var i = 0; i <= days; i++) {
          dates.add(startDate.add(Duration(days: i)));
        }
        break;
      case SavingsInterval.weekly:
        final weeks = (totalDuration.inDays / 7).ceil();
        for (var i = 0; i <= weeks; i++) {
          dates.add(startDate.add(Duration(days: i * 7)));
        }
        break;
      case SavingsInterval.monthly:
        final months = (totalDuration.inDays / 30).ceil();
        for (var i = 0; i <= months; i++) {
          dates.add(DateTime(startDate.year, startDate.month + i + 1, 1));
        }
        break;
      case SavingsInterval.yearly:
        final years = (totalDuration.inDays / 365).ceil();
        for (var i = 0; i <= years; i++) {
          dates.add(DateTime(startDate.year + i + 1, 1, 1));
        }
        break;
    }

    // Ensure dates don't exceed target date
    return dates
        .where((date) => targetDate == null || !date.isAfter(targetDate!))
        .toList();
  }

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

  int? get daysRemaining {
    if (targetDate == null) return null;
    final remaining = targetDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  Goal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? currency,
    DateTime? targetDate,
    String? category,
    String? description,
    bool? isCompleted,
    SavingsInterval? savingsInterval,
    double? startingAmount,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      currency: currency ?? this.currency,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      savingsInterval: savingsInterval ?? this.savingsInterval,
      startingAmount: startingAmount ?? this.startingAmount,
    );
  }
}
