import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SavingsChart extends StatelessWidget {
  final double saved;
  final double target;

  const SavingsChart({super.key, required this.saved, required this.target});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = target > 0 ? saved / target : 0;
    final double remaining = target > 0 ? target - saved : 0;

    // Determine the max Y value for the chart (the total target or the saved amount if target is 0)
    final double maxY = target > 0 ? target : saved;

    return AspectRatio(
      aspectRatio: 1.7, // Adjust aspect ratio as needed
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        color: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Progress: ${(progress * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    barTouchData: BarTouchData(
                      enabled: false,
                    ), // Disable touch for simplicity
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles:
                              false, // Hide bottom labels (Saved/Remaining)
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false, // Hide left labels (amounts)
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: false, // Hide border around the chart
                    ),
                    barGroups: [
                      BarChartGroupData(
                        x: 0, // Group for 'Saved'
                        barRods: [
                          BarChartRodData(
                            toY: saved,
                            color: theme.colorScheme.primary,
                            width: 16, // Bar width
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                        showingTooltipIndicators: [
                          0,
                        ], // Show tooltip for this rod
                      ),
                      BarChartGroupData(
                        x: 1, // Group for 'Remaining'
                        barRods: [
                          BarChartRodData(
                            toY: remaining,
                            color: theme.colorScheme.surfaceVariant,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                        showingTooltipIndicators: [0],
                      ),
                    ],
                    gridData: FlGridData(show: false), // Hide grid lines
                    alignment: BarChartAlignment.spaceAround,
                    // minX: 0,
                    // maxX: 2, // 2 groups, so max x should be 1
                    minY: 0,
                    maxY:
                        maxY > 0
                            ? maxY + (maxY * 0.1)
                            : 100, // Add some padding to maxY, or a default if target/saved is 0
                    groupsSpace: 12, // Space between bar groups
                    // No horizontal axis for labels, as per the original design
                    // No primary measure axis as per the original design
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Indicator(
                    color: theme.colorScheme.primary,
                    text: 'Saved: ₦${saved.toStringAsFixed(0)}',
                    isSquare: true,
                  ),
                  const SizedBox(width: 16),
                  _Indicator(
                    color: theme.colorScheme.surfaceVariant,
                    text: 'Remaining: ₦${remaining.toStringAsFixed(0)}',
                    isSquare: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor,
  });
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
