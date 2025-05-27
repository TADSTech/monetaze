import 'package:flutter/material.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:provider/provider.dart';
import 'package:monetaze/theme/theme_provider.dart';

class ThemedGoalCard extends StatelessWidget {
  final Goal goal;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const ThemedGoalCard({
    super.key,
    required this.goal,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal.progress;
    final daysRemaining =
        goal.targetDate?.difference(DateTime.now()).inDays ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      color:
          isSelected
              ? theme.colorScheme.primary.withOpacity(0.05)
              : theme.colorScheme.surface,
      elevation: isSelected ? 4 : 1,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with name and delete button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress section
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Linear progress and amounts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amounts row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saved: ${goal.currency}${goal.currentAmount.toStringAsFixed(0)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                              ),
                            ),
                            Text(
                              'Goal: ${goal.currency}${goal.targetAmount.toStringAsFixed(0)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Linear progress bar
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.surfaceVariant
                              .withOpacity(0.5),
                          color:
                              progress >= 1
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.primary,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),

                        // Savings information
                        if (goal.targetDate != null && daysRemaining > 0) ...[
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      'Save ${goal.currency}${goal.requiredPeriodicPayment.toStringAsFixed(0)} ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '${goal.intervalDescription.toLowerCase()} ',
                                ),
                                TextSpan(text: 'for ${daysRemaining} days'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Circular progress indicator
                  const SizedBox(width: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.surfaceVariant
                              .withOpacity(0.5),
                          color:
                              progress >= 1
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.primary,
                          strokeWidth: 4,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Additional info section
              if (goal.targetDate != null || goal.category != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (goal.targetDate != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.calendar_today,
                        text: 'Target: ${_formatDate(goal.targetDate!)}',
                      ),
                    if (goal.category != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.category,
                        text: goal.category!,
                      ),
                    if (goal.isCompleted)
                      _buildInfoChip(
                        context,
                        icon: Icons.check_circle,
                        text: 'Completed',
                        color: theme.colorScheme.tertiary,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
