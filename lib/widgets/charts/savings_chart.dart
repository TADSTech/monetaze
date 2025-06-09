import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SavingsChart extends StatelessWidget {
  final double saved;
  final double target;
  final String currency;

  const SavingsChart({
    super.key,
    required this.saved,
    required this.target,
    this.currency = '₦',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        target > 0 ? min(saved / target, 1.0) : 0; // Cap progress at 100%
    final remaining =
        target > 0
            ? max(target - saved, 0)
            : 0; // Ensure remaining isn't negative

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Savings Progress',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Main chart with progress indicator
          _buildMainChart(
            context,
            theme,
            progress.toDouble(),
            saved,
            remaining.toDouble(),
          ),
          const SizedBox(height: 24),
          // Detailed information
          _buildSavingsDetails(context, saved, remaining.toDouble(), currency),
        ],
      ),
    );
  }

  Widget _buildMainChart(
    BuildContext context,
    ThemeData theme,
    double progress,
    double saved,
    double remaining,
  ) {
    return Row(
      children: [
        // Progress circle
        _buildProgressCircle(theme, progress),
        const SizedBox(width: 24),
        // Expanded pie chart
        Expanded(child: _buildPieChart(context, theme, saved, remaining)),
      ],
    );
  }

  Widget _buildProgressCircle(ThemeData theme, double progress) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(
                  0.5,
                ),
                color: theme.colorScheme.primary,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'Complete',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPieChart(
    BuildContext context,
    ThemeData theme,
    double saved,
    double remaining,
  ) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: PieChart(
        PieChartData(
          sections: _buildPieSections(theme, saved, remaining),
          centerSpaceRadius: 30,
          sectionsSpace: 0,
          borderData: FlBorderData(show: false),
          startDegreeOffset: -90, // Start from top
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {},
            enabled: false, // Disable touch interactions
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    ThemeData theme,
    double saved,
    double remaining,
  ) {
    final total = saved + remaining;
    final hasSavings = saved > 0;
    final hasRemaining = remaining > 0;

    return [
      if (hasSavings)
        PieChartSectionData(
          color: theme.colorScheme.primary,
          value: saved,
          title: '${(saved / total * 100).toStringAsFixed(0)}%',
          radius: 24,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
          titlePositionPercentageOffset: 0.55,
          badgePositionPercentageOffset: 0.98,
          showTitle:
              hasSavings && saved / total > 0.1, // Only show if enough space
        ),
      if (hasRemaining)
        PieChartSectionData(
          color: theme.colorScheme.secondaryContainer,
          value: remaining,
          title: '${(remaining / total * 100).toStringAsFixed(0)}%',
          radius: 20,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          titlePositionPercentageOffset: 0.55,
          badgePositionPercentageOffset: 0.98,
          showTitle: hasRemaining && remaining / total > 0.1,
        ),
    ];
  }

  Widget _buildSavingsDetails(
    BuildContext context,
    double saved,
    double remaining,
    String currency,
  ) {
    final theme = Theme.of(context);
    final total = saved + remaining;

    return Column(
      children: [
        _buildSavingsRow(
          theme,
          label: 'Saved',
          value: saved,
          total: total,
          color: theme.colorScheme.primary,
          currency: currency,
        ),
        const SizedBox(height: 8),
        _buildSavingsRow(
          theme,
          label: 'Remaining',
          value: remaining,
          total: total,
          color: theme.colorScheme.secondaryContainer,
          currency: currency,
        ),
        const SizedBox(height: 8),
        Divider(color: theme.colorScheme.outline.withOpacity(0.2), height: 24),
        const SizedBox(height: 8),
        _buildSavingsRow(
          theme,
          label: 'Target',
          value: total,
          total: total,
          color: theme.colorScheme.tertiary,
          currency: currency,
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildSavingsRow(
    ThemeData theme, {
    required String label,
    required double value,
    required double total,
    required Color color,
    required String currency,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          '$currency${value.toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (total > 0) ...[
          const SizedBox(width: 8),
          Text(
            '(${(value / total * 100).toStringAsFixed(0)}%)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }
}
