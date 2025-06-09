import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/services/hive_services.dart';
import 'package:monetaze/views/tasks/tasks_view.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController _fundAmountController = TextEditingController();
  int _completeConfirmationCount = 0;
  int _fundConfirmationCount = 0;
  bool _isEditingDescription = false;
  bool _isEditingCategory = false;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editedGoal = widget.goal;
    _descriptionController.text = _editedGoal.description ?? '';
    _categoryController.text = _editedGoal.category ?? ''; // Initialize
    HiveService.goalsBox.listenable().addListener(_listenToGoalChanges);
  }

  @override
  void dispose() {
    _fundAmountController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose(); // Dispose
    HiveService.goalsBox.listenable().removeListener(_listenToGoalChanges);
    super.dispose();
  }

  void _listenToGoalChanges() {
    final updatedGoal = HiveService.goalsBox.get(widget.goal.id);
    if (updatedGoal != null && updatedGoal != _editedGoal) {
      setState(() {
        _editedGoal = updatedGoal;
        if (_editedGoal.isCompleted) {
          _completeConfirmationCount = 0;
        }
      });
    }
  }

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
                  'You need to save ${_editedGoal.currency}${_editedGoal.originalPeriodicPayment.toStringAsFixed(0)} '
                  '${_editedGoal.intervalDescription.toLowerCase()} to reach your goal',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_editedGoal.daysRemaining != null) ...[
                  const SizedBox(height: 12),
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
              ElevatedButton(
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

  Future<void> _fundGoal() async {
    final String amountText = _fundAmountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackbar('Please enter an amount to fund.', Colors.red);
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackbar('Please enter a valid positive number.', Colors.red);
      return;
    }

    _fundConfirmationCount++;
    String message;
    bool shouldFund = false;

    if (_fundConfirmationCount == 1) {
      message =
          'Are you sure you want to add ${_editedGoal.currency}$amount to this goal?';
    } else if (_fundConfirmationCount == 2) {
      message =
          'This will bring your total to ${_editedGoal.currency}${_editedGoal.currentAmount + amount}. Confirm?';
    } else {
      message = 'Funds added successfully!';
      shouldFund = true;
    }

    if (!shouldFund) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Confirm Funding'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fundConfirmationCount = 0;
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fundGoal(); // Recursive call for next confirmation
                  },
                  child: const Text('Confirm'),
                ),
              ],
            ),
      );
      return;
    }

    try {
      await HiveService.fundGoal(_editedGoal.id, amount);
      _fundAmountController.clear();
      _fundConfirmationCount = 0;
      _showSnackbar(message, Colors.green);
      if ((_editedGoal.currentAmount + amount) >= _editedGoal.targetAmount) {
        // Only close if goal is now complete
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error funding goal: $e');
      _showSnackbar('Failed to fund goal: ${e.toString()}', Colors.red);
    }
  }

  void _toggleDescriptionEditing() {
    setState(() {
      _isEditingDescription = !_isEditingDescription;
      if (!_isEditingDescription &&
          _descriptionController.text != _editedGoal.description) {
        _saveDescription();
      }
    });
  }

  Future<void> _saveDescription() async {
    try {
      final updatedGoal = _editedGoal.copyWith(
        description: _descriptionController.text,
      );
      await HiveService.updateGoal(updatedGoal);
      setState(() {
        _editedGoal = updatedGoal;
      });
      _showSnackbar('Description updated!', Colors.green);
    } catch (e) {
      _showSnackbar('Failed to update description', Colors.red);
    }
  }

  void _toggleCategoryEditing() {
    // New method for category editing
    setState(() {
      _isEditingCategory = !_isEditingCategory;
      if (!_isEditingCategory &&
          _categoryController.text != _editedGoal.category) {
        _saveCategory();
      }
    });
  }

  Future<void> _saveCategory() async {
    // New method for saving category
    try {
      final updatedGoal = _editedGoal.copyWith(
        category: _categoryController.text,
      );
      await HiveService.updateGoal(updatedGoal);
      setState(() {
        _editedGoal = updatedGoal;
      });
      _showSnackbar('Category updated!', Colors.green);
    } catch (e) {
      _showSnackbar('Failed to update category', Colors.red);
    }
  }

  Future<void> _handleMarkComplete() async {
    if (_editedGoal.isCompleted) {
      await HiveService.markGoalAsCompleted(_editedGoal.id, false);
      _showSnackbar('Goal marked incomplete.', Colors.green);
      widget.onFinish();
    }

    _completeConfirmationCount++;
    String message;
    bool shouldClose = false;

    if (_completeConfirmationCount == 1) {
      message = 'Are you sure you want to mark this goal as complete?';
    } else if (_completeConfirmationCount == 2) {
      message = 'This will fully fund the goal if not already. Confirm?';
    } else if (_completeConfirmationCount == 3) {
      message = 'Are you 100% sure?. Confirm?';
    } else if (_completeConfirmationCount == 4) {
      message = 'Last chance! This action cannot be easily undone. Confirm?';
    } else {
      message = 'Goal marked as complete! Congratulations!';
      shouldClose = true;
      await HiveService.markGoalAsCompleted(
        _editedGoal.id,
      ); // Mark as complete in Hive
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(shouldClose ? 'Goal Completed!' : 'Confirm Completion'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (shouldClose) {
                    Navigator.pop(context);
                    widget.onFinish();
                  }
                },
                child: Text(shouldClose ? 'OK' : 'Cancel'),
              ),
              if (!shouldClose)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleMarkComplete();
                  },
                  child: const Text('Confirm'),
                ),
            ],
          ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = _editedGoal.isCompleted;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          // Added SingleChildScrollView
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _editedGoal.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Progress section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_editedGoal.currency}${_editedGoal.currentAmount.toStringAsFixed(0)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${_editedGoal.currency}${_editedGoal.targetAmount.toStringAsFixed(0)}',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _editedGoal.progress,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      color:
                          _editedGoal.progress >= 1
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.primary,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(_editedGoal.progress * 100).toInt()}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (!isCompleted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fund Goal',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _fundAmountController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Amount',
                                  prefixText: _editedGoal.currency,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _fundGoal,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: theme.colorScheme.secondary,
                                foregroundColor: theme.colorScheme.onSecondary,
                              ),
                              child: const Text('Add Funds'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Chips row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_editedGoal.targetDate != null)
                      _InfoChip(
                        icon: Icons.calendar_today,
                        label: _formatDate(_editedGoal.targetDate!),
                      ),
                    // Modified category chip to be editable
                    if (_editedGoal.category != null || _isEditingCategory)
                      _buildCategoryChip(context),
                    _InfoChip(
                      icon: Icons.repeat,
                      label: _editedGoal.intervalDescription,
                      onPressed: _showIntervalInfo,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (_editedGoal.description != null ||
                    _isEditingDescription) ...[
                  Row(
                    children: [
                      Text(
                        'Description',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isEditingDescription ? Icons.check : Icons.edit,
                          size: 18,
                        ),
                        onPressed: _toggleDescriptionEditing,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isEditingDescription
                      ? TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                      : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(
                            0.3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _editedGoal.description ?? 'No description',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  const SizedBox(height: 24),
                ],

                // Tasks button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _navigateToTasks,
                    icon: const Icon(Icons.task, size: 20),
                    label: const Text('View Related Tasks'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _handleMarkComplete,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor:
                              isCompleted
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              isCompleted
                                  ? Theme.of(context).colorScheme.onTertiary
                                  : Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: Center(
                          child: Text(
                            isCompleted ? 'Mark Incomplete' : 'Mark Complete',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCategoryChip(BuildContext context) {
    return ActionChip(
      avatar: Icon(Icons.category, size: 16),
      label:
          _isEditingCategory
              ? SizedBox(
                width: 100,
                child: TextField(
                  controller: _categoryController,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _toggleCategoryEditing(),
                ),
              )
              : Text(_editedGoal.category ?? 'No Category'),
      onPressed: _toggleCategoryEditing,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _InfoChip({required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
    );
  }
}
