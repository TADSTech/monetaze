import 'package:flutter/material.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/views/tasks/tasks_view.dart';

class GoalDialog extends StatefulWidget {
  final Goal goal;
  final VoidCallback onFund;
  final VoidCallback onFinish;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GoalDialog({
    super.key,
    required this.goal,
    required this.onFund,
    required this.onFinish,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<GoalDialog> {
  late Goal _editedGoal;

  @override
  void initState() {
    super.initState();
    _editedGoal = widget.goal;
  }

  // Add this method to your GoalDialog
  void _navigateToTasks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TasksView(associatedGoal: widget.goal),
      ),
    );
  }

  void _showIntervalInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Savings Plan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You need to save ${_editedGoal.currency}${_editedGoal.requiredPeriodicPayment.toStringAsFixed(0)} '
                  '${_editedGoal.intervalDescription.toLowerCase()} to reach your goal',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_editedGoal.daysRemaining != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_editedGoal.daysRemaining} days remaining',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToTasks();
                },
                child: const Text('Create Tasks'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_editedGoal.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_editedGoal.currency}${_editedGoal.currentAmount.toStringAsFixed(0)}'
                  ' of ${_editedGoal.currency}${_editedGoal.targetAmount.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${(_editedGoal.progress * 100).toInt()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _editedGoal.progress,
              backgroundColor: theme.colorScheme.surfaceVariant,
              color:
                  _editedGoal.progress >= 1
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_editedGoal.targetDate != null)
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_formatDate(_editedGoal.targetDate!)),
                    onPressed: () {},
                  ),
                if (_editedGoal.category != null)
                  ActionChip(
                    avatar: const Icon(Icons.category, size: 16),
                    label: Text(_editedGoal.category!),
                    onPressed: () {},
                  ),
                ActionChip(
                  avatar: const Icon(Icons.repeat, size: 16),
                  label: Text(_editedGoal.intervalDescription),
                  onPressed: _showIntervalInfo,
                ),
                if (_editedGoal.isCompleted)
                  ActionChip(
                    avatar: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    label: const Text('Completed'),
                    backgroundColor: theme.colorScheme.tertiary.withOpacity(
                      0.1,
                    ),
                    onPressed: () {},
                  ),
              ],
            ),
            if (_editedGoal.description != null) ...[
              const SizedBox(height: 16),
              Text('Description:', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(_editedGoal.description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _navigateToTasks,
              icon: const Icon(Icons.task),
              label: const Text('View Related Tasks'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: widget.onFinish,
          child: Text(
            _editedGoal.isCompleted ? 'Mark Incomplete' : 'Mark Complete',
          ),
        ),
        TextButton(onPressed: widget.onEdit, child: const Text('Edit')),
        TextButton(
          onPressed: widget.onDelete,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: const Text('Delete'),
        ),
        // Add this button to your dialog content
        OutlinedButton.icon(
          onPressed: _navigateToTasks,
          icon: const Icon(Icons.task),
          label: const Text('View Payment Tasks'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
