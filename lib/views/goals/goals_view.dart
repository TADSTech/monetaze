import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:monetaze/core/services/hive_services.dart';
import 'package:monetaze/views/settings/settings_view.dart';
import 'package:monetaze/widgets/cards/goal_card.dart';
import 'package:monetaze/widgets/dialogs/goal_dialog.dart';
import 'package:monetaze/widgets/dialogs/create_goal_dialog.dart';
import 'package:monetaze/views/tasks/tasks_view.dart';
import 'package:uuid/uuid.dart';

class GoalsView extends StatefulWidget {
  const GoalsView({super.key});

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> {
  final List<String> _selectedGoalIds = [];
  bool _isLoading = true;
  late final Box<Goal> _goalsBox;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      _goalsBox = await Hive.openBox<Goal>('goals');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      await Hive.deleteBoxFromDisk('goals');
      _goalsBox = await Hive.openBox<Goal>('goals');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Goal> get _filteredGoals {
    final goals = _goalsBox.values.toList();
    if (_searchQuery.isEmpty) return goals;

    return goals.where((goal) {
      final nameMatch = goal.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final categoryMatch =
          goal.category?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
          false;
      final descriptionMatch =
          goal.description?.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ??
          false;
      return nameMatch || categoryMatch || descriptionMatch;
    }).toList();
  }

  void _toggleGoalSelection(String goalId) {
    setState(() {
      if (_selectedGoalIds.contains(goalId)) {
        _selectedGoalIds.remove(goalId);
      } else {
        _selectedGoalIds.add(goalId);
      }
    });
  }

  Future<void> _addNewGoal() async {
    final newGoal = await showDialog<Goal>(
      context: context,
      builder: (context) => const CreateGoalDialog(),
    );

    if (newGoal != null) {
      try {
        await _goalsBox.put(newGoal.id, newGoal);
        await generateTasksForGoal(newGoal);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created goal and generated savings tasks'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create goal: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> checkAndRegenerateTasks() async {
    final goalsBox = await Hive.openBox<Goal>('goals');
    for (final goal in goalsBox.values) {
      await generateTasksForGoal(goal);
    }
  }

  Future<void> _deleteGoal(String goalId) async {
    await _goalsBox.delete(goalId);
    if (mounted) {
      setState(() => _selectedGoalIds.remove(goalId));
    }
  }

  Future<void> _deleteSelectedGoals() async {
    for (final id in _selectedGoalIds) {
      await _goalsBox.delete(id);
    }
    if (mounted) {
      setState(() => _selectedGoalIds.clear());
    }
  }

  Future<void> generateTasksForGoal(Goal goal) async {
    try {
      final tasksBox = await Hive.openBox<Task>('tasks');
      final now = DateTime.now();

      if (goal.targetDate == null) {
        debugPrint('No target date set for goal ${goal.name}');
        return;
      }

      final daysRemaining = goal.targetDate!.difference(now).inDays;
      if (daysRemaining <= 0) {
        debugPrint('Goal ${goal.name} has already passed its target date');
        return;
      }

      // Clear existing tasks for this goal
      final existingTasks =
          tasksBox.values
              .where((t) => t.goalId == goal.id)
              .map((t) => t.id)
              .toList();

      await Future.wait(existingTasks.map((id) => tasksBox.delete(id)));

      // Calculate payment amount with safety checks
      final paymentAmount = goal.originalPeriodicPayment;
      if (paymentAmount <= 0) {
        debugPrint('Invalid payment amount for goal ${goal.name}');
        return;
      }

      // Generate new tasks based on interval
      switch (goal.savingsInterval) {
        case SavingsInterval.daily:
          for (var i = 0; i < daysRemaining; i++) {
            final dueDate = now.add(Duration(days: i));
            final task = Task(
              id: const Uuid().v4(),
              goalId: goal.id,
              title: 'Daily savings for ${goal.name}',
              dueDate: dueDate,
              amount: paymentAmount,
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);
          }
          break;

        case SavingsInterval.weekly:
          final weeks = (daysRemaining / 7).ceil();
          for (var i = 0; i < weeks; i++) {
            final dueDate = now.add(Duration(days: i * 7));
            final task = Task(
              id: const Uuid().v4(),
              goalId: goal.id,
              title: 'Weekly savings for ${goal.name} (Week ${i + 1})',
              dueDate: dueDate,
              amount: paymentAmount,
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);
          }
          break;

        case SavingsInterval.monthly:
          final months = (daysRemaining / 30).ceil();
          for (var i = 0; i < months; i++) {
            final dueDate = DateTime(now.year, now.month + i + 1, 1);
            final task = Task(
              id: const Uuid().v4(),
              goalId: goal.id,
              title:
                  'Monthly savings for ${goal.name} (${DateFormat('MMM y').format(dueDate)})',
              dueDate: dueDate,
              amount: paymentAmount,
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);
          }
          break;

        case SavingsInterval.yearly:
          final years = (daysRemaining / 365).ceil();
          for (var i = 0; i < years; i++) {
            final dueDate = DateTime(now.year + i + 1, 1, 1);
            final task = Task(
              id: const Uuid().v4(),
              goalId: goal.id,
              title: 'Yearly savings for ${goal.name} (${dueDate.year})',
              dueDate: dueDate,
              amount: paymentAmount,
              currency: goal.currency,
            );
            await tasksBox.put(task.id, task);
          }
          break;
      }

      debugPrint('Generated tasks for goal ${goal.name} successfully');
    } catch (e) {
      debugPrint('Error generating tasks for goal: $e');
      rethrow;
    }
  }

  void _showGoalDialog(Goal goal) {
    showDialog(
      context: context,
      builder:
          (context) => GoalDialog(
            goal: goal,
            onFund: () => Navigator.pop(context),
            onFinish: () => Navigator.pop(context),
            onEdit: () => Navigator.pop(context),
            onDelete: () {
              Navigator.pop(context);
              _deleteGoal(goal.id);
            },
          ),
    );
  }

  void _navigateToTasks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => const TasksView(
              regenerateTasks: false,
              isComingFromGoals: true,
            ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'tasks_btn',
            onPressed: _navigateToTasks,
            mini: true,
            child: const Icon(Icons.task),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'add_goal_btn',
            onPressed: _addNewGoal,
            icon: const Icon(Icons.add),
            label: const Text('New Goal'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _goalsBox.listenable(),
        builder: (context, Box<Goal> box, _) {
          final goals = _filteredGoals;
          final completedCount = goals.where((g) => g.isCompleted).length;
          final activeCount = goals.length - completedCount;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                title: const Text('Goals'),
                floating: true,
                snap: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name, category...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                _searchQuery.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged:
                              (value) => setState(() => _searchQuery = value),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatChip(
                              context,
                              value: activeCount,
                              label: 'Active',
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            _buildStatChip(
                              context,
                              value: completedCount,
                              label: 'Completed',
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            _buildStatChip(
                              context,
                              value: goals.fold<int>(
                                0,
                                (sum, g) => sum + g.currentAmount.toInt(),
                              ),
                              label: 'Saved',
                              color: Theme.of(context).colorScheme.secondary,
                              isAmount: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_selectedGoalIds.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedGoalIds.length} selected',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: _deleteSelectedGoals,
                        ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver:
                    goals.isEmpty
                        ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No goals found',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Create your first goal'
                                      : 'No matches for "$_searchQuery"',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final goal = goals[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ThemedGoalCard(
                                goal: goal,
                                isSelected: _selectedGoalIds.contains(goal.id),
                                onTap: () => _showGoalDialog(goal),
                                onLongPress:
                                    () => _toggleGoalSelection(goal.id),
                                onDelete: () => _deleteGoal(goal.id),
                              ),
                            );
                          }, childCount: goals.length),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required int value,
    required String label,
    required Color color,
    bool isAmount = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isAmount ? '₦$value' : value.toString(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }
}
