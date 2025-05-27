import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:monetaze/core/services/notification_service.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:monetaze/views/tasks/task_service.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class TasksView extends StatefulWidget {
  final Goal? associatedGoal;

  const TasksView({super.key, this.associatedGoal});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView>
    with SingleTickerProviderStateMixin {
  late final Box<Task> _tasksBox;
  late final Box<Goal> _goalsBox;
  bool _isLoading = true;
  final RefreshController _refreshController = RefreshController();
  late TabController _tabController;

  // Task categories
  List<Task> _todayTasks = [];
  List<Task> _upcomingTasks = [];
  List<Task> _overdueTasks = [];
  List<Task> _completedTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initHive();
    _checkForMissedTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _initHive() async {
    _tasksBox = await Hive.openBox<Task>('tasks');
    _goalsBox = await Hive.openBox<Goal>('goals');
    _categorizeTasks();
    if (mounted) setState(() => _isLoading = false);
  }

  void _categorizeTasks() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final allTasks =
        widget.associatedGoal != null
            ? _tasksBox.values
                .where((t) => t.goalId == widget.associatedGoal!.id)
                .toList()
            : _tasksBox.values.toList();

    // Today tasks - due between today 00:00 and tomorrow 00:00
    _todayTasks =
        allTasks.where((task) {
          return !task.isCompleted &&
              task.dueDate.isAfter(todayStart) &&
              task.dueDate.isBefore(todayEnd);
        }).toList();

    // Upcoming tasks - due after today
    _upcomingTasks =
        allTasks.where((task) {
          return !task.isCompleted && task.dueDate.isAfter(todayEnd);
        }).toList();

    // Overdue tasks - due before now and not completed
    _overdueTasks =
        allTasks.where((task) {
          return !task.isCompleted &&
              task.dueDate.isBefore(now) &&
              !_todayTasks.contains(task);
        }).toList();

    // Completed tasks
    _completedTasks = allTasks.where((task) => task.isCompleted).toList();

    // Sorting
    _todayTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    _upcomingTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    _overdueTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    _completedTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
  }

  Future<void> _checkForMissedTasks() async {
    final now = DateTime.now();
    final missedTasks =
        _tasksBox.values
            .where((task) => !task.isCompleted && task.dueDate.isBefore(now))
            .length;

    if (missedTasks > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have $missedTasks overdue payments'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _completeTask(Task task, double amount) async {
    final goal = _goalsBox.get(task.goalId);
    if (goal != null) {
      goal.currentAmount += amount;
      await _goalsBox.put(goal.id, goal);
    }

    task.isCompleted = true;
    await TaskService.updateTaskStatus(task);
    await NotificationService().cancelNotification(
      task,
    ); // Cancel any pending notification
    _categorizeTasks();

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment completed! ₦${amount.toStringAsFixed(0)} added',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showCompleteDialog(Task task) async {
    final amountController = TextEditingController(
      text: task.amount.toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Complete Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Amount to add to goal:'),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: '₦',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => amountController.clear(),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  final amount =
                      double.tryParse(amountController.text) ?? task.amount;
                  _completeTask(task, amount);
                  Navigator.pop(context);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  Future<void> _onRefresh() async {
    try {
      if (widget.associatedGoal != null) {
        await TaskService.generateTasksForGoal(widget.associatedGoal!);
      } else {
        final goalsBox = await Hive.openBox<Goal>('goals');
        for (final goal in goalsBox.values) {
          await TaskService.generateTasksForGoal(goal);
        }
      }
      _categorizeTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tasks refreshed'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      _refreshController.refreshCompleted();
      if (mounted) setState(() {});
    }
  }

  Future<void> _completeTaskWithConfirmations(Task task) async {
    // First confirmation - Basic confirmation
    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Payment'),
            content: Text(
              'Are you sure you want to complete this payment of '
              '${task.currency}${task.amount.toStringAsFixed(0)} '
              'for ${_goalsBox.get(task.goalId)?.name ?? 'this goal'}?',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
    );

    if (firstConfirm != true) return;

    // Second confirmation - Amount verification
    final amountController = TextEditingController(
      text: task.amount.toStringAsFixed(0),
    );

    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Verify Amount'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please verify the payment amount:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: task.currency,
                    border: const OutlineInputBorder(),
                    labelText: 'Amount',
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Back',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Confirm Amount',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
    );

    if (secondConfirm != true) return;

    // Third confirmation - Final confirmation
    final bool? thirdConfirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Final Confirmation'),
            content: Text(
              'You are about to mark this payment as completed. '
              'This action cannot be undone.\n\n'
              'Amount: ${task.currency}${amountController.text}\n'
              'Goal: ${_goalsBox.get(task.goalId)?.name ?? 'Unknown'}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Complete Payment',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
    );

    if (thirdConfirm == true) {
      final amount = double.tryParse(amountController.text) ?? task.amount;
      await _completeTask(task, amount);
    }
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final goal = _goalsBox.get(task.goalId);
        final isOverdue = _overdueTasks.contains(task);
        final isToday = _todayTasks.contains(task);
        final isCompleted = _completedTasks.contains(task);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color:
                  isOverdue
                      ? Theme.of(context).colorScheme.error
                      : Colors.transparent,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        goal?.name ?? 'General Savings',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isToday
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('MMM d, y').format(task.dueDate),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              isToday
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          '${task.currency}${task.amount.toStringAsFixed(0)}',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    if (!isCompleted)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isOverdue
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                          foregroundColor:
                              isOverdue
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _completeTaskWithConfirmations(task),
                        child: Text(isOverdue ? 'Pay Now' : 'Complete'),
                      )
                    else
                      const SizedBox(width: 80), // Maintain consistent spacing
                  ],
                ),
                if (isOverdue) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Overdue',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.associatedGoal?.name ?? 'Payment Schedule',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _onRefresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              child: Text(
                'Today',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            Tab(
              child: Text(
                'Upcoming',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            Tab(
              child: Text(
                'Overdue',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            Tab(
              child: Text(
                'Completed',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        header: CustomHeader(
          builder: (context, mode) {
            return Center(
              child: SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
            );
          },
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTaskList(_todayTasks),
            _buildTaskList(_upcomingTasks),
            _buildTaskList(_overdueTasks),
            _buildTaskList(_completedTasks),
          ],
        ),
      ),
    );
  }
}
