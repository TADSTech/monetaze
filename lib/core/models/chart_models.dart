import 'dart:ui';

class SavingsChartData {
  final DateTime date;
  final double amount;
  final String currency;

  SavingsChartData({
    required this.date,
    required this.amount,
    required this.currency,
  });
}

class GoalProgressSeries {
  final String goalName;
  final double currentAmount;
  final double targetAmount;
  final String currency;

  GoalProgressSeries({
    required this.goalName,
    required this.currentAmount,
    required this.targetAmount,
    required this.currency,
  });
}

class ActivityTimelineData {
  final DateTime date;
  final double amount;
  final bool isDeposit;
  final String category;

  ActivityTimelineData({
    required this.date,
    required this.amount,
    required this.isDeposit,
    required this.category,
  });
}

class InsightsStats {
  final double totalSaved;
  final int activeGoals;
  final int completedGoals;
  final int paymentsMade;
  final String currency;

  InsightsStats({
    required this.totalSaved,
    required this.activeGoals,
    required this.completedGoals,
    required this.paymentsMade,
    required this.currency,
  });
}

class ChartLegendItem {
  final Color color;
  final String label;

  ChartLegendItem({required this.color, required this.label});
}

enum InsightsViewState { loading, loaded, error, offline }
