import 'dart:io';

import 'package:flutter/material.dart';
import 'package:monetaze/core/models/user_model.dart';
import 'package:monetaze/core/services/hive_services.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:monetaze/views/settings/settings_view.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart'; // Used for FlexSchemeData and highContrastColor extension.
import 'package:intl/intl.dart';

/// A user profile view allowing users to see and edit their personal information,
/// financial goals, and app settings like theme.
class UserView extends StatefulWidget {
  const UserView({super.key});

  @override
  State<UserView> createState() => _UserViewState();
}

class _UserViewState extends State<UserView> {
  User? _currentUser;
  bool _isLoading = true;
  bool _isEditing = false;
  File?
  _selectedImageFile; // Stores the file path of the newly selected profile image.

  final _formKey =
      GlobalKey<FormState>(); // Key for validating the profile form.
  final _nameController = TextEditingController();
  final _genderController = TextEditingController();
  final _goalController = TextEditingController();
  final _emailController = TextEditingController();
  final Uuid _uuid =
      const Uuid(); // Used for generating unique IDs for new users.
  final ImagePicker _picker =
      ImagePicker(); // For picking images from the device gallery.

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Asynchronously loads user data from Hive and populates the form fields.
  /// Handles potential errors during data loading and updates the loading state.
  Future<void> _loadUserData() async {
    try {
      final user = await HiveService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        _nameController.text = user.name;
        _genderController.text = user.gender ?? '';
        _goalController.text = user.financialGoal ?? '';
        _emailController.text = user.email ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user data: $e'); // Log the error for debugging.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _isLoading = false,
        ); // Ensure loading state is updated even on error.
      }
    }
  }

  /// Prompts the user to pick an image from their gallery.
  /// Updates the `_selectedImageFile` state variable if an image is chosen.
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Optimize image size for performance.
        maxHeight: 800,
        imageQuality: 85, // Compress image quality.
      );
      if (pickedFile != null) {
        setState(() => _selectedImageFile = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e'); // Log the error.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
      }
    }
  }

  /// Validates the form fields and saves the user data to Hive.
  /// Creates a new user if one doesn't exist, otherwise updates the current user.
  /// Updates the `ThemeProvider` and shows a success/failure message.
  Future<void> _saveUserData() async {
    if (!(_formKey.currentState?.validate() ?? false))
      return; // Validate form before saving.

    setState(() => _isLoading = true);

    try {
      // Create a new User object with updated fields.
      // If _currentUser is null, a new User object is created with a new ID and creation timestamp.
      final newUser = (_currentUser ??
              User(
                id: _uuid.v4(),
                name: '', // Will be updated by controller text.
                createdAt: DateTime.now(),
                themeMode:
                    ThemeMode.system, // Default theme settings for a new user.
                themeIndex: 0,
              ))
          .copyWith(
            name: _nameController.text,
            email:
                _emailController.text.isNotEmpty ? _emailController.text : null,
            gender:
                _genderController.text.isNotEmpty
                    ? _genderController.text
                    : null,
            financialGoal:
                _goalController.text.isNotEmpty ? _goalController.text : null,
            profileImagePath:
                _selectedImageFile?.path ?? _currentUser?.profileImagePath,
            updatedAt: DateTime.now(), // Update the last updated timestamp.
          );

      await HiveService.saveCurrentUser(newUser);

      // Update the ThemeProvider to reflect any changes in user-specific theme preferences.
      Provider.of<ThemeProvider>(context, listen: false).setUser(newUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _currentUser = newUser;
          _isEditing = false; // Exit editing mode after successful save.
        });
      }
    } catch (e) {
      debugPrint('Error saving user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    // Dispose all TextEditingControllers to prevent memory leaks.
    _nameController.dispose();
    _genderController.dispose();
    _goalController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dateFormat =
        DateFormat.yMMMMd(); // Date formatter for displaying dates.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Display a loading indicator if an operation is in progress,
          // otherwise show the edit/save button.
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator.adaptive(),
            )
          else
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () async {
                if (_isEditing) {
                  await _saveUserData(); // Save data if currently editing.
                } else {
                  setState(() => _isEditing = true); // Enter editing mode.
                }
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(),
              ) // Show full-screen loading for initial data fetch.
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          // Display the user's profile picture or a default icon.
                          CircleAvatar(
                            radius: 70,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage:
                                _selectedImageFile != null
                                    ? FileImage(
                                      _selectedImageFile!,
                                    ) // New image selected.
                                    : (_currentUser?.profileImagePath != null
                                        ? FileImage(
                                          File(_currentUser!.profileImagePath!),
                                        ) // Existing image.
                                        : null), // No image available.
                            child:
                                _selectedImageFile == null &&
                                        _currentUser?.profileImagePath == null
                                    ? Icon(
                                      Icons.person,
                                      size: 70,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    )
                                    : null,
                          ),
                          // Display camera icon for picking image only when in editing mode.
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.camera_alt,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Personal Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Form for editable personal details.
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildEditableField(
                            context,
                            controller: _nameController,
                            label: 'Name',
                            hintText: 'Enter your name',
                            icon: Icons.person,
                            isRequired: true,
                          ),
                          const SizedBox(height: 16),
                          _buildEditableField(
                            context,
                            controller: _emailController,
                            label: 'Email',
                            hintText: 'Enter your email',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildEditableField(
                            context,
                            controller: _genderController,
                            label: 'Gender',
                            hintText: 'Male/Female/Other',
                            icon: Icons.transgender,
                          ),
                          const SizedBox(height: 16),
                          _buildEditableField(
                            context,
                            controller: _goalController,
                            label: 'Financial Goal',
                            hintText: 'Describe your financial aspirations',
                            icon: Icons.flag,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Details',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Display static account information.
                    _buildInfoCard(
                      context,
                      title: 'Member Since',
                      value: dateFormat.format(
                        _currentUser?.createdAt ??
                            DateTime.now(), // Fallback to current time if null.
                      ),
                      icon: Icons.calendar_today,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      context,
                      title: 'Last Updated',
                      value: dateFormat.format(
                        _currentUser?.updatedAt ??
                            DateTime.now(), // Fallback to current time if null.
                      ),
                      icon: Icons.update,
                    ),
                    const SizedBox(height: 32),
                    // Action buttons for settings and data management.
                    _buildSettingsButton(context),
                    const SizedBox(height: 16),
                    _buildThemeSettingsButton(context, themeProvider),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          // Show a confirmation dialog before clearing user data.
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Clear Data?'),
                                  content: const Text(
                                    'This will remove all your profile data. Are you sure?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text(
                                        'Confirm',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                          );

                          if (confirmed == true) {
                            await HiveService.clearCurrentUser(); // Clear all user data from Hive.
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'User data cleared. Please restart app.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Clear User Data',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  /// Builds a customizable [TextFormField] for editable user profile fields.
  /// Handles validation for required fields and applies styling based on editing mode.
  Widget _buildEditableField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        filled: !_isEditing, // Background color when not editing.
        enabled:
            _isEditing, // Enable/disable input based on `_isEditing` state.
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator:
          isRequired
              ? (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
              : null,
    );
  }

  /// Builds a display card for static user information (e.g., join date, last updated).
  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a button styled as a card to navigate to the general app settings.
  Widget _buildSettingsButton(BuildContext context) {
    return _buildActionCard(
      context,
      icon: Icons.settings,
      title: 'App Settings',
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsView()),
          ),
    );
  }

  /// Builds a button styled as a card to open the theme selection dialog.
  /// Displays the current theme's primary color as a visual indicator.
  Widget _buildThemeSettingsButton(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    final theme = Theme.of(context);

    return _buildActionCard(
      context,
      icon: Icons.palette,
      title: 'Theme Color',
      trailing: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color:
              theme
                  .colorScheme
                  .primary, // Show the current primary theme color.
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
        ),
      ),
      onTap: () => _showThemeSelectionDialog(themeProvider),
    );
  }

  /// A reusable widget to create an action card with an icon, title, and optional trailing widget.
  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays an [AlertDialog] allowing the user to select from available theme colors.
  void _showThemeSelectionDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Theme Color'),
          content: SizedBox(
            width: double.maxFinite, // Allow content to take max width.
            child: GridView.builder(
              shrinkWrap: true, // Only take necessary space.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio:
                    2.5, // Adjust aspect ratio for better display.
              ),
              itemCount: themeProvider.availableThemes.length,
              itemBuilder: (context, index) {
                final scheme = themeProvider.availableThemes[index];
                return InkWell(
                  onTap: () {
                    themeProvider.setTheme(index); // Apply selected theme.
                    Navigator.pop(context); // Close the dialog.
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          scheme
                              .data
                              .light
                              .primary, // Show the primary color of the theme scheme.
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            themeProvider.themeIndex == index
                                ? Colors
                                    .white // Highlight the currently selected theme.
                                : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        // Format theme name (e.g., 'BLUE_LIGHT' becomes 'BLUE LIGHT').
                        scheme.name.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: scheme.data.light.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
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
}
