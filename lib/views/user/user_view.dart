import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:monetaze/core/models/user_model.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:monetaze/views/settings/settings_view.dart';
import 'package:provider/provider.dart';

class UserView extends StatefulWidget {
  const UserView({super.key});

  @override
  State<UserView> createState() => _UserViewState();
}

class _UserViewState extends State<UserView> {
  late final Box<User> _userBox;
  User? _currentUser;
  bool _isLoading = true;
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _genderController = TextEditingController();
  final _goalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _userBox = await Hive.openBox<User>('user');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _userBox.get('current_user');
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });

    // If no user exists, start in edit mode
    if (user == null) {
      setState(() => _isEditing = true);
    } else {
      _nameController.text = user.name;
      _genderController.text = user.gender ?? '';
      _goalController.text = user.financialGoal ?? '';
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    final newUser = User(
      id: 'current_user',
      name: _nameController.text,
      gender: _genderController.text.isNotEmpty ? _genderController.text : null,
      financialGoal:
          _goalController.text.isNotEmpty ? _goalController.text : null,
    );

    await _userBox.put('current_user', newUser);
    setState(() {
      _currentUser = newUser;
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully!')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (_currentUser != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isEditing) _buildEditForm(theme),
            if (!_isEditing && _currentUser != null) _buildProfileView(theme),

            const SizedBox(height: 32),
            _buildSettingsButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tell us about yourself',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _genderController,
            decoration: const InputDecoration(
              labelText: 'Gender (Optional)',
              prefixIcon: Icon(Icons.transgender),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _goalController,
            decoration: const InputDecoration(
              labelText: 'Financial Goal (Optional)',
              prefixIcon: Icon(Icons.flag),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _saveUserData,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Profile'),
          ),

          if (_currentUser != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isEditing = false),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 50,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 24),

        _buildProfileItem('Name', _currentUser!.name, Icons.person, theme),
        if (_currentUser!.gender != null)
          _buildProfileItem(
            'Gender',
            _currentUser!.gender!,
            Icons.transgender,
            theme,
          ),
        if (_currentUser!.financialGoal != null)
          _buildProfileItem(
            'Financial Goal',
            _currentUser!.financialGoal!,
            Icons.flag,
            theme,
          ),
      ],
    );
  }

  Widget _buildProfileItem(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
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
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsView(),
            fullscreenDialog: true,
          ),
        );
      },
      icon: const Icon(Icons.settings),
      label: const Text('App Settings'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
