import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:monetaze/core/base/main_wrapper_notifier.dart';
import 'package:monetaze/core/models/chart_models.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/quote_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:monetaze/core/models/user_model.dart';
import 'package:monetaze/core/services/hive_services.dart';
import 'package:monetaze/core/services/quote_service.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:monetaze/views/user/user_view.dart';
import 'package:monetaze/widgets/cards/theme_card.dart';
import 'package:monetaze/widgets/charts/savings_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

class HomeView extends StatefulWidget {
  final QuoteService quoteService;
  const HomeView({super.key, required this.quoteService});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  late AnimationController _refreshController;
  late Animation<double> _refreshAnimation;
  String userName = 'User';
  User? _currentUser;
  String motivationalQuote = 'Loading...';
  double totalSavings = 0;
  double totalTarget = 0;
  String savingsCurrency = '₦';
  List<Goal> goals = [];
  List<ActivityTimelineData> recentActivities = [];
  List<Task> upcomingTasks = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _refreshAnimation = CurvedAnimation(
      parent: _refreshController,
      curve: Curves.easeInOut,
    );
    _initData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      await _loadUserData();
      await _loadQuote();
      await _loadFinancialData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = await HiveService.getCurrentUser();
    setState(() {
      _currentUser = user;
      userName = user?.name ?? 'User';
    });
  }

  Future<void> _loadQuote() async {
    try {
      final quote = await widget.quoteService.fetchRandomQuote();
      if (mounted) {
        setState(() {
          motivationalQuote = '${quote.text} - ${quote.author}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          motivationalQuote = 'Consistent savings lead to financial freedom.';
        });
      }
    }
  }

  Future<void> _loadFinancialData() async {
    try {
      HiveService.tasksBox;
      HiveService.goalsBox;
    } catch (e) {
      debugPrint('Error accessing Hive boxes in _loadFinancialData: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await Future.wait([_loadUserData(), _loadQuote(), _loadFinancialData()]);
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to refresh data'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _navigateToUserProfile(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const UserView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _viewAllGoals(BuildContext context) {
    Provider.of<MainWrapperNotifier>(context, listen: false).currentIndex = 1;
  }

  void _viewAllTasks(BuildContext context) {
    Provider.of<MainWrapperNotifier>(context, listen: false).currentIndex = 2;
  }

  void _viewAllActivity(BuildContext context) {
    Provider.of<MainWrapperNotifier>(context, listen: false).currentIndex = 3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return _buildSimpleLoading(theme);
    }

    if (_hasError) {
      return _buildErrorState(theme);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        displacement: 40,
        edgeOffset: 20,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildUserCard(theme, _currentUser),
              ),
              pinned: true,
              elevation: 0,
              backgroundColor: theme.colorScheme.primaryContainer,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    // Savings Overview Section - Now reactive to tasks and goals changes
                    ValueListenableBuilder<Box<Task>>(
                      valueListenable: HiveService.tasksBox.listenable(),
                      builder: (context, tasksBox, _) {
                        final completedTasks =
                            tasksBox.values
                                .where((task) => task.isCompleted)
                                .toList();
                        final totalSavings = completedTasks.fold<double>(
                          0,
                          (sum, task) => sum + task.amount,
                        );
                        String savingsCurrency =
                            completedTasks.isNotEmpty
                                ? completedTasks.first.currency
                                : '₦'; // Default currency

                        return ValueListenableBuilder<Box<Goal>>(
                          valueListenable: HiveService.goalsBox.listenable(),
                          builder: (context, goalsBox, _) {
                            final allGoals = goalsBox.values.toList();
                            final activeGoals =
                                allGoals
                                    .where((goal) => !goal.isCompleted)
                                    .toList();
                            final totalTarget = activeGoals.fold<double>(
                              0,
                              (sum, goal) =>
                                  sum +
                                  (goal.targetAmount - goal.currentAmount),
                            );

                            // If savingsCurrency is still default and goals have a currency, use goal's currency
                            if (savingsCurrency == '₦' &&
                                activeGoals.isNotEmpty) {
                              savingsCurrency = activeGoals.first.currency;
                            }

                            return _buildSavingsSection(
                              context,
                              saved: totalSavings,
                              target: totalTarget,
                              currency: savingsCurrency,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Goals Progress Section - Now reactive to goals changes
                    ValueListenableBuilder<Box<Goal>>(
                      valueListenable: HiveService.goalsBox.listenable(),
                      builder: (context, box, _) {
                        final allGoals = box.values.toList();
                        final activeGoals =
                            allGoals
                                .where((goal) => !goal.isCompleted)
                                .toList();
                        final goals =
                            activeGoals.take(3).toList(); // Top 3 active goals
                        return _buildGoalsSection(context, goals: goals);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Upcoming Tasks Section - Now reactive to tasks changes
                    ValueListenableBuilder<Box<Task>>(
                      valueListenable: HiveService.tasksBox.listenable(),
                      builder: (context, box, _) {
                        final pendingTasks =
                            box.values
                                .where((task) => !task.isCompleted)
                                .toList();
                        final overdueTasks =
                            box.values
                                .where(
                                  (task) =>
                                      !task.isCompleted &&
                                      task.dueDate.isBefore(DateTime.now()),
                                )
                                .toList();
                        final allDueTasks = [...pendingTasks, ...overdueTasks];
                        allDueTasks.sort(
                          (a, b) => a.dueDate.compareTo(b.dueDate),
                        ); // Sort by due date
                        final upcomingTasks =
                            allDueTasks.take(3).toList(); // Next 3
                        return _buildTasksSection(
                          context,
                          tasks: upcomingTasks,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Recent Activity Section - Now reactive to tasks changes
                    ValueListenableBuilder<Box<Task>>(
                      valueListenable: HiveService.tasksBox.listenable(),
                      builder: (context, box, _) {
                        final completedTasks =
                            box.values
                                .where((task) => task.isCompleted)
                                .toList();
                        // Sort completed tasks by date descending to get most recent
                        completedTasks.sort(
                          (a, b) => b.dueDate.compareTo(a.dueDate),
                        );
                        final recentActivities =
                            completedTasks.take(5).map((task) {
                              // Ensure we get the goal associated with the task for category
                              final goal = HiveService.goalsBox.get(
                                task.goalId,
                              );
                              return ActivityTimelineData(
                                date: task.dueDate,
                                amount: task.amount,
                                isDeposit:
                                    true, // Assuming completed tasks represent deposits
                                category: goal?.name ?? 'General Savings',
                              );
                            }).toList();
                        return _buildActivitySection(
                          context,
                          activities: recentActivities,
                        );
                      },
                    ),

                    // Bottom Padding
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(ThemeData theme, User? user) {
    // Get padding from media query for safe area handling
    final mediaQueryPadding = MediaQuery.of(context).padding;
    final topPadding = mediaQueryPadding.top;

    return GestureDetector(
      onTap: () => _navigateToUserProfile(context),
      child: Container(
        color: theme.colorScheme.primaryContainer,
        // Adjust padding to account for status bar/notch
        padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Profile Picture display
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.onPrimaryContainer
                      .withOpacity(0.1),
                  backgroundImage:
                      user?.profileImagePath != null
                          ? FileImage(File(user!.profileImagePath!))
                          : null, // Display image if path exists
                  child:
                      user?.profileImagePath == null
                          ? Icon(
                            Icons.person,
                            size: 32,
                            color: theme.colorScheme.onPrimaryContainer,
                          )
                          : null, // Show icon only if no image path
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                      ),
                      Text(
                        user?.name ?? 'User', // Use user?.name here
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isRefreshing)
                  RotationTransition(
                    turns: _refreshAnimation,
                    child: Icon(
                      Icons.refresh,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                motivationalQuote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary, // Use theme's primary color
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your financial data...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/error.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          Text('Failed to load data', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(
            'Please check your connection and try again',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _initData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
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
    final progress =
        target > 0 ? min(saved / target, 1.0) : 0; // Cap progress at 100%
    final progressPercentage = (progress * 100); // Convert to percentage

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.savings,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Savings Overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Savings Overview'),
                            content: const Text(
                              'This section shows your total savings progress. '
                              'The chart displays your monthly savings pattern, '
                              'while the numbers show your overall progress.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Total Saved',
                    value: '$currency${saved.toStringAsFixed(0)}',
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Remaining',
                    value:
                        '$currency${max(target - saved, 0).toStringAsFixed(0)}',
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Progress',
                    value: '${progressPercentage.toStringAsFixed(0)}%',
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SavingsChart(saved: saved, target: target, currency: currency),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSection(BuildContext context, {required List<Goal> goals}) {
    final theme = Theme.of(context);
    final activeGoalsCount =
        HiveService.goalsBox.values.where((goal) => !goal.isCompleted).length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.flag,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Active Goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (activeGoalsCount > 3)
                  TextButton(
                    onPressed: () => _viewAllGoals(context),
                    child: Text(
                      'View All ($activeGoalsCount)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.flag,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active goals',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => _viewAllGoals(context),
                      child: const Text('Create a Goal'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < goals.length; i++)
                    _buildGoalItem(context, i, goals[i]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(BuildContext context, int index, Goal goal) {
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
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          color: theme.colorScheme.primary,
                          strokeWidth: 4,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
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
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          color: theme.colorScheme.primary,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${goal.currency}${goal.currentAmount.toStringAsFixed(0)} '
                          'of ${goal.currency}${goal.targetAmount.toStringAsFixed(0)}',
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

  Widget _buildTasksSection(BuildContext context, {required List<Task> tasks}) {
    final theme = Theme.of(context);
    final pendingTasksCount =
        HiveService.tasksBox.values.where((task) => !task.isCompleted).length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.task,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Upcoming Payments',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (pendingTasksCount > 3)
                  TextButton(
                    onPressed: () => _viewAllTasks(context),
                    child: Text(
                      'View All ($pendingTasksCount)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.task_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No upcoming payments',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < tasks.length; i++)
                    _buildTaskItem(context, i, tasks[i]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, int index, Task task) {
    final theme = Theme.of(context);
    final goal = HiveService.goalsBox.get(task.goalId);
    final isOverdue = task.dueDate.isBefore(DateTime.now());

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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          isOverdue
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOverdue ? Icons.warning : Icons.payment,
                      color:
                          isOverdue
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal?.name ?? 'General Savings',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, y').format(task.dueDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${task.currency}${task.amount.toStringAsFixed(0)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isOverdue)
                        Text(
                          'Overdue',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivitySection(
    BuildContext context, {
    required List<ActivityTimelineData> activities,
  }) {
    final theme = Theme.of(context);
    final completedTasksCount =
        HiveService.tasksBox.values.where((task) => task.isCompleted).length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.history,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (completedTasksCount > 5)
                  TextButton(
                    onPressed: () => _viewAllActivity(context),
                    child: Text(
                      'View All ($completedTasksCount)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (activities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < activities.length; i++)
                    _buildActivityItem(context, i, activities[i]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    int index,
    ActivityTimelineData activity,
  ) {
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          activity.isDeposit
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activity.isDeposit
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color:
                          activity.isDeposit
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.category,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      fontWeight: FontWeight.bold,
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
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}
