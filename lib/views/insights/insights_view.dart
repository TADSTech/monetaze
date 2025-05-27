import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:monetaze/core/models/chart_models.dart';
import 'package:shimmer/shimmer.dart';

class InsightsView extends StatefulWidget {
  const InsightsView({super.key});

  @override
  State<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends State<InsightsView>
    with TickerProviderStateMixin {
  final RefreshController _refreshController = RefreshController();
  late AnimationController _loadingAnimationController;
  final ValueNotifier<bool> _hasConnection = ValueNotifier(true);

  // State management
  final _stateNotifier = ValueNotifier<InsightsViewState>(
    InsightsViewState.loading,
  );

  // Chart data
  final _monthlySavingsData = ValueNotifier<List<SavingsChartData>>([]);
  final _goalProgressData = ValueNotifier<List<GoalProgressSeries>>([]);
  final _recentActivityData = ValueNotifier<List<ActivityTimelineData>>([]);

  // Stats data
  final _statsData = ValueNotifier<InsightsStats?>(null);

  // Hive boxes
  late final Box<Goal> _goalsBox;
  late final Box<Task> _tasksBox;

  // Responsive layout
  late bool _isLargeScreen;
  late double _chartHeight;

  @override
  void initState() {
    super.initState();
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Initialize with default values
    _isLargeScreen = false;
    _chartHeight = 200;

    _initHive();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateResponsiveValues();
  }

  void _calculateResponsiveValues() {
    final mediaQuery = MediaQuery.of(context);
    setState(() {
      _isLargeScreen = mediaQuery.size.width > 600;
      _chartHeight = _isLargeScreen ? 280 : 200;
    });
  }

  Future<void> _initHive() async {
    try {
      _stateNotifier.value = InsightsViewState.loading;

      _goalsBox = await Hive.openBox<Goal>('goals').onError((
        error,
        stackTrace,
      ) {
        _stateNotifier.value = InsightsViewState.error;
        throw error!;
      });

      _tasksBox = await Hive.openBox<Task>('tasks').onError((
        error,
        stackTrace,
      ) {
        _stateNotifier.value = InsightsViewState.error;
        throw error!;
      });

      await _loadChartData();
    } catch (e) {
      _stateNotifier.value = InsightsViewState.error;
      _showErrorSnackbar('Failed to initialize data storage');
    }
  }

  Future<void> _loadChartData() async {
    try {
      if (!_hasConnection.value) {
        _stateNotifier.value = InsightsViewState.offline;
        return;
      }

      final now = DateTime.now();
      final dateFormat = DateFormat('MMM yyyy');
      final currencyFormat = NumberFormat.currency(symbol: '₦');

      // Monthly savings data
      final monthlySavings = <String, double>{};
      final completedTasks =
          _tasksBox.values
              .where((task) => task.isCompleted)
              .toList()
              .cast<Task>();

      for (var task in completedTasks) {
        final monthKey = dateFormat.format(task.dueDate);
        monthlySavings.update(
          monthKey,
          (value) => value + task.amount,
          ifAbsent: () => task.amount,
        );
      }

      _monthlySavingsData.value =
          monthlySavings.entries
              .map(
                (entry) => SavingsChartData(
                  date: dateFormat.parse(entry.key),
                  amount: entry.value,
                  currency:
                      completedTasks.isNotEmpty
                          ? completedTasks.first.currency
                          : '₦',
                ),
              )
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      // Goal progress data
      _goalProgressData.value =
          _goalsBox.values
              .map(
                (goal) => GoalProgressSeries(
                  goalName: goal.name,
                  currentAmount: goal.currentAmount,
                  targetAmount: goal.targetAmount,
                  currency: goal.currency,
                ),
              )
              .toList();

      // Recent activity data
      _recentActivityData.value =
          completedTasks.take(10).map((task) {
              final goal = _goalsBox.get(task.goalId);
              return ActivityTimelineData(
                date: task.dueDate,
                amount: task.amount,
                isDeposit: true,
                category: goal?.name ?? 'General Savings',
              );
            }).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      // Calculate stats
      final totalSaved = completedTasks.fold<double>(
        0,
        (sum, task) => sum + task.amount,
      );
      final activeGoals =
          _goalsBox.values.where((goal) => !goal.isCompleted).length;
      final completedGoals =
          _goalsBox.values.where((goal) => goal.isCompleted).length;

      _statsData.value = InsightsStats(
        totalSaved: totalSaved,
        activeGoals: activeGoals,
        completedGoals: completedGoals,
        paymentsMade: completedTasks.length,
        currency:
            completedTasks.isNotEmpty ? completedTasks.first.currency : '₦',
      );

      _stateNotifier.value = InsightsViewState.loaded;
    } catch (e) {
      _stateNotifier.value = InsightsViewState.error;
      _showErrorSnackbar('Failed to load data: ${e.toString()}');
    }
  }

  Future<void> _onRefresh() async {
    try {
      await _loadChartData();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
      _showErrorSnackbar('Refresh failed: ${e.toString()}');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildMonthlySavingsChart() {
    return ValueListenableBuilder<List<SavingsChartData>>(
      valueListenable: _monthlySavingsData,
      builder: (context, data, _) {
        if (data.isEmpty) {
          return _buildEmptyState(
            icon: Icons.trending_up,
            title: 'No Savings Data',
            subtitle: 'Complete some tasks to see your savings trend',
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          margin: EdgeInsets.all(_isLargeScreen ? 24 : 16),
          child: _ResponsiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Monthly Savings',
                  icon: Icons.bar_chart,
                  onInfoPressed:
                      () => _showChartInfoDialog(
                        title: 'Monthly Savings',
                        content:
                            'This chart shows your savings pattern over time. Each bar represents the total amount saved in that month.',
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: _chartHeight,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          data
                              .map((e) => e.amount)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (BarChartGroupData group) {
                            return Theme.of(context).colorScheme.surface;
                          },
                          tooltipBorder: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 0.5,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final chartData = data[groupIndex];
                            return BarTooltipItem(
                              '${chartData.currency}${chartData.amount.toStringAsFixed(0)}\n${DateFormat('MMM y').format(chartData.date)}',
                              TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final date = data[value.toInt()].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MMM').format(date),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: _isLargeScreen ? 12 : 10,
                                  ),
                                ),
                              );
                            },
                            reservedSize: _isLargeScreen ? 40 : 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: _isLargeScreen ? 50 : 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${data.isNotEmpty ? data.first.currency : ''}${value.toInt()}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: _isLargeScreen ? 12 : 10,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval:
                            data
                                .map((e) => e.amount)
                                .reduce((a, b) => a > b ? a : b) /
                            5,
                        getDrawingHorizontalLine:
                            (value) => FlLine(
                              color: Theme.of(context).dividerColor,
                              strokeWidth: 0.5,
                            ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups:
                          data.asMap().entries.map((entry) {
                            final index = entry.key;
                            final chartData = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: chartData.amount,
                                  color: Theme.of(context).colorScheme.primary,
                                  width: _isLargeScreen ? 20 : 16,
                                  borderRadius: BorderRadius.circular(4),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: data
                                        .map((e) => e.amount)
                                        .reduce((a, b) => a > b ? a : b),
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceVariant,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                ),
                if (_isLargeScreen) ...[
                  const SizedBox(height: 16),
                  _buildChartLegend(
                    items: [
                      ChartLegendItem(
                        color: Theme.of(context).colorScheme.primary,
                        label: 'Monthly Savings',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoalProgressChart() {
    return ValueListenableBuilder<List<GoalProgressSeries>>(
      valueListenable: _goalProgressData,
      builder: (context, data, _) {
        if (data.isEmpty) {
          return _buildEmptyState(
            icon: Icons.flag,
            title: 'No Goals Data',
            subtitle: 'Create some goals to track your progress',
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(
            horizontal: _isLargeScreen ? 24 : 16,
            vertical: _isLargeScreen ? 8 : 0,
          ),
          child: _ResponsiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Goal Progress',
                  icon: Icons.stacked_bar_chart,
                  onInfoPressed:
                      () => _showChartInfoDialog(
                        title: 'Goal Progress',
                        content:
                            'This chart compares your current savings against your target for each goal. The lighter bars show the target, while the darker bars show your current progress.',
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: _chartHeight,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          data
                              .map((e) => e.targetAmount)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (BarChartGroupData group) {
                            return Theme.of(context).colorScheme.surface;
                          },
                          tooltipBorder: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 0.5,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final goalData = data[groupIndex];
                            final progress = (goalData.currentAmount /
                                    goalData.targetAmount *
                                    100)
                                .toStringAsFixed(1);
                            return BarTooltipItem(
                              '${goalData.goalName}\nProgress: $progress%\n${goalData.currency}${goalData.currentAmount.toStringAsFixed(0)} of ${goalData.currency}${goalData.targetAmount.toStringAsFixed(0)}',
                              TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final goal = data[value.toInt()];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: _isLargeScreen ? 80 : 60,
                                  child: Text(
                                    goal.goalName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                                      fontSize: _isLargeScreen ? 12 : 10,
                                    ),
                                  ),
                                ),
                              );
                            },
                            reservedSize: _isLargeScreen ? 60 : 50,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: _isLargeScreen ? 50 : 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${data.isNotEmpty ? data.first.currency : ''}${value.toInt()}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: _isLargeScreen ? 12 : 10,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval:
                            data
                                .map((e) => e.targetAmount)
                                .reduce((a, b) => a > b ? a : b) /
                            5,
                        getDrawingHorizontalLine:
                            (value) => FlLine(
                              color: Theme.of(context).dividerColor,
                              strokeWidth: 0.5,
                            ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups:
                          data.asMap().entries.map((entry) {
                            final index = entry.key;
                            final goalData = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: goalData.targetAmount,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                  width: _isLargeScreen ? 20 : 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                BarChartRodData(
                                  toY: goalData.currentAmount,
                                  color: Theme.of(context).colorScheme.primary,
                                  width: _isLargeScreen ? 20 : 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                ),
                if (_isLargeScreen) ...[
                  const SizedBox(height: 16),
                  _buildChartLegend(
                    items: [
                      ChartLegendItem(
                        color: Theme.of(context).colorScheme.primary,
                        label: 'Current Progress',
                      ),
                      ChartLegendItem(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        label: 'Target Amount',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityList() {
    return ValueListenableBuilder<List<ActivityTimelineData>>(
      valueListenable: _recentActivityData,
      builder: (context, data, _) {
        if (data.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No Recent Activity',
            subtitle: 'Your completed tasks will appear here',
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          margin: EdgeInsets.all(_isLargeScreen ? 24 : 16),
          child: _ResponsiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Recent Activity',
                  icon: Icons.history_toggle_off,
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: data.length,
                  separatorBuilder:
                      (context, index) => Divider(
                        height: 24,
                        color: Theme.of(context).dividerColor,
                      ),
                  itemBuilder: (context, index) {
                    final activity = data[index];
                    return _ActivityListItem(
                      activity: activity,
                      isLargeScreen: _isLargeScreen,
                    );
                  },
                ),
                if (data.length >= 10) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Implement view all activity
                      },
                      child: Text(
                        'View All Activity',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsOverview() {
    return ValueListenableBuilder<InsightsStats?>(
      valueListenable: _statsData,
      builder: (context, stats, _) {
        if (stats == null) {
          return _buildShimmerStats();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          margin: EdgeInsets.all(_isLargeScreen ? 24 : 16),
          child: _ResponsiveCard(
            child: Column(
              children: [
                if (_isLargeScreen) ...[
                  _SectionHeader(
                    title: 'Savings Overview',
                    icon: Icons.insights,
                  ),
                  const SizedBox(height: 16),
                ],
                GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: _isLargeScreen ? 4 : 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: _isLargeScreen ? 1.5 : 1.8,
                  children: [
                    _StatItem(
                      icon: Icons.savings,
                      value:
                          '${stats.currency}${stats.totalSaved.toStringAsFixed(0)}',
                      label: 'Total Saved',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    _StatItem(
                      icon: Icons.flag,
                      value: stats.activeGoals.toString(),
                      label: 'Active Goals',
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    _StatItem(
                      icon: Icons.check_circle,
                      value: stats.completedGoals.toString(),
                      label: 'Completed Goals',
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    _StatItem(
                      icon: Icons.payments,
                      value: stats.paymentsMade.toString(),
                      label: 'Payments Made',
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceVariant,
        highlightColor: Theme.of(context).colorScheme.surface,
        child: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: _isLargeScreen ? 4 : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: _isLargeScreen ? 1.5 : 1.8,
          children: List.generate(
            4,
            (index) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend({required List<ChartLegendItem> items}) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children:
          items
              .map(
                (item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChartInfoDialog({
    required String title,
    required String content,
  }) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Got it'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InsightsViewState>(
      valueListenable: _stateNotifier,
      builder: (context, state, _) {
        if (state == InsightsViewState.loading) {
          return _buildLoadingState();
        }

        if (state == InsightsViewState.error) {
          return _buildErrorState();
        }

        if (state == InsightsViewState.offline) {
          return _buildOfflineState();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Insights'),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: _hasConnection,
                builder: (context, hasConnection, _) {
                  return Tooltip(
                    message:
                        hasConnection
                            ? 'Refresh data'
                            : 'Offline - data may be outdated',
                    child: IconButton(
                      icon: Icon(
                        hasConnection ? Icons.refresh : Icons.cloud_off,
                        color:
                            hasConnection
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.error,
                      ),
                      onPressed: hasConnection ? _onRefresh : null,
                    ),
                  );
                },
              ),
            ],
          ),
          body: SmartRefresher(
            controller: _refreshController,
            onRefresh: _onRefresh,
            physics: const BouncingScrollPhysics(),
            header: CustomHeader(
              builder: (context, mode) {
                return Center(
                  child: SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return _buildDesktopLayout();
                }
                return _buildMobileLayout();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            _buildStatsOverview(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildMonthlySavingsChart()),
                Expanded(child: _buildGoalProgressChart()),
              ],
            ),
            _buildRecentActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        _buildStatsOverview(),
        _buildMonthlySavingsChart(),
        _buildGoalProgressChart(),
        _buildRecentActivityList(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _loadingAnimationController,
              child: Icon(
                Icons.savings,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Crunching your numbers...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _initHive, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Offline - Showing cached data',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildMobileLayout()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _loadingAnimationController.dispose();
    _hasConnection.dispose();
    _stateNotifier.dispose();
    _monthlySavingsData.dispose();
    _goalProgressData.dispose();
    _recentActivityData.dispose();
    _statsData.dispose();
    super.dispose();
  }
}

// Custom widget for responsive cards
class _ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _ResponsiveCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// Custom widget for section headers
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onInfoPressed;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.onInfoPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (onInfoPressed != null)
          IconButton(
            icon: Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onPressed: onInfoPressed,
          ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(12), // Keep padding consistent
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        // Consider adding a subtle border for definition, especially in light themes
        border: Border.all(
          color: color.withOpacity(0.2), // Slightly darker border
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon and Label
          Row(
            // Ensure the row takes only necessary space horizontally
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18, // Slightly larger icon for better visibility
                color: color,
              ),
              const SizedBox(width: 8),
              // Use Expanded or Flexible for text that might overflow
              Expanded(
                // Using Expanded forces the text to take available space and then handle overflow
                child: Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(
                      0.7,
                    ), // Slightly less opaque
                    fontWeight:
                        FontWeight.w500, // Make label a bit bolder for clarity
                  ),
                  overflow:
                      TextOverflow.ellipsis, // Critical for preventing overflow
                  maxLines: 1, // Ensure label doesn't wrap to multiple lines
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Spacing between label row and value
          // Value Text
          Expanded(
            // Use Expanded for the value text as well
            child: Align(
              // Align the value text to the start (left)
              alignment: Alignment.topLeft,
              child: Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  // Adjust font size for better fit in smaller containers
                  fontSize:
                      textTheme.titleLarge?.fontSize!, // Reduce size slightly
                ),
                overflow:
                    TextOverflow.ellipsis, // Critical for preventing overflow
                maxLines:
                    2, // Allow value to wrap if necessary, but no more than 2 lines
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom widget for activity list items
class _ActivityListItem extends StatelessWidget {
  final ActivityTimelineData activity;
  final bool isLargeScreen;

  const _ActivityListItem({
    required this.activity,
    required this.isLargeScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: isLargeScreen ? 48 : 40,
          height: isLargeScreen ? 48 : 40,
          decoration: BoxDecoration(
            color:
                activity.isDeposit
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            activity.isDeposit ? Icons.arrow_upward : Icons.arrow_downward,
            color:
                activity.isDeposit
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onErrorContainer,
            size: isLargeScreen ? 24 : 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.category,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                DateFormat('MMM d, y').format(activity.date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${activity.isDeposit ? '+' : '-'}${activity.amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color:
                activity.isDeposit
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
