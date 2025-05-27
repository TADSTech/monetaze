import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:monetaze/core/base/main_wrapper_notifier.dart';
import 'package:monetaze/core/models/chart_models.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/quote_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:monetaze/core/models/user_model.dart';
import 'package:monetaze/core/services/quote_service.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:monetaze/widgets/cards/theme_card.dart';
import 'package:monetaze/widgets/charts/savings_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:monetaze/main.dart';

class HomeView extends StatefulWidget {
  final QuoteService quoteService;
  const HomeView({super.key, required this.quoteService});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final Box<Goal> _goalsBox;
  late final Box<Task> _tasksBox;
  late final Box<User> _userBox;
  late final Box<MotivationalQuote> _quotesBox;

  String userName = 'User';
  String motivationalQuote = 'Loading...';
  double totalMonthlySavings = 0;
  double totalMonthlyTarget = 0;
  String savingsCurrency = '₦';
  List<Goal> goals = [];
  List<ActivityTimelineData> recentActivities = [];
  late final QuoteService _quoteService;

  @override
  void initState() {
    super.initState();
    _quoteService = widget.quoteService;
    _initHive();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    try {
      final quote = await _quoteService.fetchRandomQuote();
      setState(() {
        motivationalQuote = '${quote.text} - ${quote.author}';
      });
    } catch (e) {
      setState(() {
        motivationalQuote = 'Saving consistently leads to financial freedom.';
      });
    }
  }

  Future<void> _initHive() async {
    _goalsBox = await Hive.openBox<Goal>('goals');
    _tasksBox = await Hive.openBox<Task>('tasks');
    _userBox = await Hive.openBox<User>('user');
    _quotesBox = await Hive.openBox<MotivationalQuote>('quotes');
    _loadData();
  }

  Future<void> _loadData() async {
    // Load user data
    final user = _userBox.get('current_user');
    if (user != null) {
      setState(() {
        userName = user.name;
      });
    } else {
      setState(() {
        userName = 'User'; // Default name if no user exists
      });
    }

    final savedQuotes = await _quoteService.getSavedQuotes();
    if (savedQuotes.isNotEmpty) {
      // Get the most recent quote
      final recentQuote = savedQuotes.first;
      motivationalQuote = '${recentQuote.text} - ${recentQuote.author}';
    } else {
      // If no saved quotes, fetch a new one
      final newQuote = await _quoteService.fetchRandomQuote();
      motivationalQuote = '${newQuote.text} - ${newQuote.author}';
    }

    // Calculate monthly savings from completed tasks
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final completedTasks =
        _tasksBox.values
            .where(
              (task) => task.isCompleted && task.dueDate.isAfter(currentMonth),
            )
            .toList();

    totalMonthlySavings = completedTasks.fold<double>(
      0,
      (sum, task) => sum + task.amount,
    );

    if (completedTasks.isNotEmpty) {
      savingsCurrency = completedTasks.first.currency;
    }

    // Calculate monthly target from active goals
    final activeGoals =
        _goalsBox.values.where((goal) => !goal.isCompleted).toList();

    totalMonthlyTarget = activeGoals.fold<double>(
      0,
      (sum, goal) => sum + (goal.targetAmount - goal.currentAmount),
    );

    // Prepare goals list
    goals = activeGoals.take(3).toList();

    // Prepare recent activities
    recentActivities =
        completedTasks.take(3).map((task) {
          final goal = _goalsBox.get(task.goalId);
          return ActivityTimelineData(
            date: task.dueDate,
            amount: task.amount,
            isDeposit: true,
            category: goal?.name ?? 'General Savings',
          );
        }).toList();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercentage =
        totalMonthlyTarget > 0
            ? (totalMonthlySavings / totalMonthlyTarget) * 100
            : 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Header Card
            ThemeCard(
              title: 'Welcome back, $userName',
              subtitle: motivationalQuote,
              logo: const Icon(Icons.person_outline, size: 28),
              onTap: () => _showUserProfile(context),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              usePrimaryContainer: true,
              titleSize: 22,
              subtitleSize: 15,
              tightPadding: true,
            ),

            // Main Content Container
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  // Savings Overview Section
                  _buildSavingsSection(
                    context,
                    saved: totalMonthlySavings,
                    target: totalMonthlyTarget,
                    currency: savingsCurrency,
                  ),

                  const Divider(height: 0, indent: 16, endIndent: 16),

                  // Goals Progress Section
                  _buildGoalsSection(context, goals: goals),

                  const Divider(height: 0, indent: 16, endIndent: 16),

                  // Recent Activity Section
                  _buildActivitySection(context, activities: recentActivities),
                ],
              ),
            ),

            // Bottom Padding
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // ==================== Section Builders ====================

  Widget _buildSavingsSection(
    BuildContext context, {
    required double saved,
    required double target,
    required String currency,
  }) {
    final theme = Theme.of(context);
    final progress = target > 0 ? saved / target : 0;

    return _buildSection(
      context,
      icon: Icons.savings_outlined,
      title: 'Monthly Savings',
      content: Column(
        children: [
          // Summary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                context,
                title: 'Saved',
                value: '$currency${saved.toStringAsFixed(0)}',
                color: theme.colorScheme.primary,
              ),
              _buildStatCard(
                context,
                title: 'Target',
                value: '$currency${target.toStringAsFixed(0)}',
                color: theme.colorScheme.secondary,
              ),
              _buildStatCard(
                context,
                title: 'Progress',
                value: '${(progress * 100).toStringAsFixed(1)}%',
                color: theme.colorScheme.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          SavingsChart(saved: saved, target: target),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGoalsSection(BuildContext context, {required List<Goal> goals}) {
    return _buildSection(
      context,
      icon: Icons.flag_outlined,
      title: 'Goals Progress',
      content: Column(
        children: [
          for (final goal in goals.take(3)) _buildGoalItem(context, goal),
          if (_goalsBox.values.length > 3) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _viewAllGoals(context),
              child: const Text('View all goals'),
            ),
          ],
        ],
      ),
      lastItem: goals.length <= 3,
    );
  }

  Widget _buildActivitySection(
    BuildContext context, {
    required List<ActivityTimelineData> activities,
  }) {
    return _buildSection(
      context,
      icon: Icons.history_outlined,
      title: 'Recent Activity',
      content: Column(
        children: [
          for (final activity in activities.take(3))
            _buildActivityItem(context, activity),
          if (_tasksBox.values.where((task) => task.isCompleted).length >
              3) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _viewAllActivity(context),
              child: const Text('View all activity'),
            ),
          ],
        ],
      ),
      lastItem: true,
    );
  }

  // ==================== Component Builders ====================

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget content,
    bool lastItem = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, lastItem ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width * 0.28;

    return Flexible(
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(BuildContext context, Goal goal) {
    final theme = Theme.of(context);
    final progress = goal.currentAmount / goal.targetAmount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Progress Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  color: theme.colorScheme.primary,
                  strokeWidth: 3,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Goal Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${goal.currency}${goal.currentAmount} of ${goal.currency}${goal.targetAmount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    ActivityTimelineData activity,
  ) {
    final theme = Theme.of(context);
    final date = _formatActivityDate(activity.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  activity.isDeposit
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : theme.colorScheme.error.withOpacity(0.1),
            ),
            child: Icon(
              activity.isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
              size: 18,
              color:
                  activity.isDeposit
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.category, style: theme.textTheme.bodyMedium),
                Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${activity.isDeposit ? '+' : '-'}${activity.amount.toStringAsFixed(0)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color:
                  activity.isDeposit
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Helper Methods ====================

  String _formatActivityDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // ==================== Navigation Methods ====================

  void _showUserProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  void _viewAllGoals(BuildContext context) {
    Provider.of<MainWrapperNotifier>(context, listen: false).currentIndex = 1;
  }

  void _viewAllActivity(BuildContext context) {
    Provider.of<MainWrapperNotifier>(context, listen: false).currentIndex = 3;
  }
}
