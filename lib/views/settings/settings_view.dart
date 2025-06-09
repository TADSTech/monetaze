import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:monetaze/core/services/notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _notificationsEnabled = false;
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
    _loadAppInfo();
  }

  Future<void> _loadNotificationStatus() async {
    final status = await NotificationService().requestPermissions();
    setState(() => _notificationsEnabled = status);
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _launchURL(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url))) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open link: $e')));
    }
  }

  void _showThemeDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: themeProvider.availableThemes.length,
              itemBuilder: (context, index) {
                final scheme = themeProvider.availableThemes[index];
                return RadioListTile<FlexScheme>(
                  title: Text(
                    scheme.name.replaceAll('_', ' ').toUpperCase(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  value: scheme,
                  groupValue: themeProvider.currentScheme,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setTheme(index);
                      // No need to pop immediately, let user browse themes
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'), // Changed from 'Cancel' to 'Close'
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Monetaze',
      applicationVersion: 'v$_appVersion (build $_buildNumber)',
      applicationIcon: const Icon(Icons.savings, size: 48),
      applicationLegalese:
          '© 2025 Monetaze: Budget, Save, Grow\nAll rights reserved',
      children: [
        const SizedBox(height: 16),
        const Text(
          'A personal finance app to help you achieve your financial goals',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              () => _launchURL(
                'https://docs.google.com/document/d/1X55M2PjAOn6GXKpOv7iMqljbIT__VnZ9YGaUZHCbfng/edit?usp=sharing',
              ),
          child: const Text('Privacy Policy'),
        ),
        TextButton(
          onPressed:
              () => _launchURL(
                'https://docs.google.com/document/d/15cnD1fOSfhMiTlJ1qz-GP4HHLmLTNuDVV0DxzYHf5hw/edit?usp=sharing',
              ),
          child: const Text('Terms of Service'),
        ),
      ],
    );
  }

  void _showDeveloperInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Developer Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thank you for using Monetaze!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'For support, feature requests, or bug reports, please contact us:',
              ),
              const SizedBox(height: 16),
              _buildContactOption(
                icon: Icons.email,
                label: 'motrenewed@gmail.com',
                onTap: () => _launchURL('mailto:motrenewed@gmail.com'),
              ),
              _buildContactOption(
                icon: Icons.code,
                label: 'Contribute on GitHub',
                onTap: () => _launchURL('https://github.com/TADSTech/monetaze'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Settings Section
          Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: _buildSection(
              context,
              title: 'App Settings',
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    themeProvider.toggleThemeMode();
                  },
                  secondary: Icon(
                    themeProvider.themeMode == ThemeMode.dark
                        ? Icons.nightlight
                        : Icons.wb_sunny,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Theme Color'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: _showThemeDialog,
                ),
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  value: _notificationsEnabled,
                  onChanged: (value) async {
                    final status =
                        await NotificationService().requestPermissions();
                    setState(() => _notificationsEnabled = status);
                  },
                  secondary: const Icon(Icons.notifications),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Support Section
          Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: _buildSection(
              context,
              title: 'Support',
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('About Monetaze'),
                  onTap: _showAboutDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.developer_mode),
                  title: const Text('Developer Information'),
                  onTap: _showDeveloperInfo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legal Section
          Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: _buildSection(
              context,
              title: 'Legal',
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  onTap: () => _launchURL('https://example.com/privacy'),
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Terms of Service'),
                  onTap: () => _launchURL('https://example.com/terms'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Save Changes Button (primarily for future settings, theme is instant)
          ElevatedButton(
            onPressed: () {
              // For theme settings, changes are already applied via notifyListeners
              // This button would be more impactful for other settings that require explicit save
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Settings saved!')));
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
          ),

          const SizedBox(height: 20), // Spacing before app version
          // App Version
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Version $_appVersion (build $_buildNumber)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
