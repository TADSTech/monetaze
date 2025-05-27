import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class ThemeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget logo;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool usePrimaryContainer;
  final double? titleSize;
  final double? subtitleSize;
  final bool tightPadding;

  const ThemeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.logo,
    this.onTap,
    this.margin,
    this.usePrimaryContainer = false,
    this.titleSize,
    this.subtitleSize,
    this.tightPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Provider.of<ThemeProvider>(context).currentScheme;

    // Color system
    final cardColor =
        usePrimaryContainer
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface;
    final textColor =
        usePrimaryContainer
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface;
    final logoBgColor =
        usePrimaryContainer
            ? theme.colorScheme.primary.withOpacity(0.1)
            : theme.colorScheme.primaryContainer.withOpacity(0.2);

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      color: cardColor,
      clipBehavior: Clip.antiAlias, // Ensures content stays within bounds
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding:
              tightPadding
                  ? const EdgeInsets.all(12)
                  : const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with customizable size
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, // Bold as requested
                        color: textColor,
                        fontSize: titleSize ?? 16,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Subtitle with customizable size
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor.withOpacity(0.8),
                        fontSize: subtitleSize ?? 14,
                        fontStyle: FontStyle.italic, // Italic as requested
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Logo container
              Container(
                constraints: const BoxConstraints(
                  minWidth: 48,
                  maxWidth: 48,
                  minHeight: 48,
                  maxHeight: 48,
                ),
                decoration: BoxDecoration(
                  color: logoBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: Center(child: logo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
