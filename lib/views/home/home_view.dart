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
import 'package:flutter_shimmer/flutter_shimmer.dart';

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
  bool _isLoading = true;

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
      if (mounted) {
        setState(() {
          motivationalQuote = '${quote.text} - ${quote.author}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          motivationalQuote = 'Saving consistently leads to financial freedom.';
        });
      }
    }
  }

  Future<void> _initHive() async {
    try {
      _goalsBox = await Hive.openBox<Goal>('goals');
      _tasksBox = await Hive.openBox<Task>('tasks');
      _userBox = await Hive.openBox<User>('user');
      _quotesBox = await Hive.openBox<MotivationalQuote>('quotes');
      await _loadData();
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        userName = 'User';
      });
    }

    final savedQuotes = await _quoteService.getSavedQuotes();
    if (savedQuotes.isNotEmpty) {
      final recentQuote = savedQuotes.first;
      setState(() {
        motivationalQuote = '${recentQuote.text} - ${recentQuote.author}';
      });
    } else {
      final newQuote = await _quoteService.fetchRandomQuote();
      setState(() {
        motivationalQuote = '${newQuote.text} - ${newQuote.author}';
      });
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
    if (_isLoading) {
      return _buildShimmerLoading();
    }

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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ThemeCard(
                key: ValueKey(userName + motivationalQuote),
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
            ),

            // Main Content Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
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

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ProfileShimmer(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              children: [
                const ListTileShimmer(
                  padding: EdgeInsets.all(16),
                  isDarkMode: false,
                ),
                const Divider(height: 0),
                ListTileShimmer(
                  padding: const EdgeInsets.all(16),
                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                ),
                const Divider(height: 0),
                ListTileShimmer(
                  padding: const EdgeInsets.all(16),
                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                // Added Flexible here
                child: _buildAnimatedStatCard(
                  context,
                  title: 'Saved',
                  value: '$currency${saved.toStringAsFixed(0)}',
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8), // Added spacing between cards
              Flexible(
                // Added Flexible here
                child: _buildAnimatedStatCard(
                  context,
                  title: 'Target',
                  value: '$currency${target.toStringAsFixed(0)}',
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 8), // Added spacing between cards
              Flexible(
                // Added Flexible here
                child: _buildAnimatedStatCard(
                  context,
                  title: 'Progress',
                  value: '${(progress * 100).toStringAsFixed(1)}%',
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: SavingsChart(
              key: ValueKey(saved + target),
              saved: saved,
              target: target,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, (1 - opacity) * 20),
            child: _buildStatCard(
              // This now returns a Container directly
              context,
              title: title,
              value: value,
              color: color,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoalsSection(BuildContext context, {required List<Goal> goals}) {
    return _buildSection(
      context,
      icon: Icons.flag_outlined,
      title: 'Goals Progress',
      content: Column(
        children: [
          for (var i = 0; i < goals.take(3).length; i++)
            AnimatedGoalItem(index: i, goal: goals[i]),
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
          for (var i = 0; i < activities.take(3).length; i++)
            AnimatedActivityItem(index: i, activity: activities[i]),
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

    return Container(
      // Changed from Flexible to Container
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
    );
  }

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

class AnimatedGoalItem extends StatelessWidget {
  final int index;
  final Goal goal;

  const AnimatedGoalItem({super.key, required this.index, required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal.currentAmount / goal.targetAmount;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * 20, 0),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
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
            ),
          ),
        );
      },
    );
  }
}

class AnimatedActivityItem extends StatelessWidget {
  final int index;
  final ActivityTimelineData activity;

  const AnimatedActivityItem({
    super.key,
    required this.index,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _formatActivityDate(activity.date);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * 20, 0),
            child: Padding(
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
                      activity.isDeposit
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
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
                        Text(
                          activity.category,
                          style: theme.textTheme.bodyMedium,
                        ),
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
            ),
          ),
        );
      },
    );
  }

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
}
