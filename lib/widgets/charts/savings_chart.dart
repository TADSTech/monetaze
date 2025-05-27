import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SavingsChart extends StatelessWidget {
  final double saved;
  final double target;

  const SavingsChart({super.key, required this.saved, required this.target});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = ((saved / target).clamp(0, 1) * 100).roundToDouble();

    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
      ),
      child: Center(
        child: PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(
                value: percentage,
                title: '${percentage.toInt()}%',
                color: theme.colorScheme.primary,
                radius: 50,
                titleStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              PieChartSectionData(
                value: 100 - percentage,
                title: '',
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                radius: 50,
              ),
            ],
            sectionsSpace: 2,
            centerSpaceRadius: 40,
          ),
        ),
      ),
    );
  }
}
