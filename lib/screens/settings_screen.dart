import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/enhanced_task_models.dart';
import '../services/enhanced_task_service.dart';
import '../utils/safe_context.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  final PocketBase pb;

  const SettingsScreen({super.key, required this.pb});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late EnhancedTaskService taskService;
  late SafeContext _safeContext;
  
  UserSettings? _userSettings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    taskService = EnhancedTaskService(widget.pb);
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeContext = SafeContext(context);
  }

  @override
  void dispose() {
    _safeContext.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await taskService.getUserSettings();
      if (mounted) {
        setState(() {
          _userSettings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _safeContext.showSnackBar('Failed to load settings: $e', Colors.red);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_userSettings == null) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      await taskService.updateUserSettings(_userSettings!);
      _safeContext.showSnackBar('Settings saved successfully!', Colors.green);
    } catch (e) {
      _safeContext.showSnackBar('Failed to save settings: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateTheme(String theme) {
    setState(() {
      _userSettings = UserSettings(
        id: _userSettings!.id,
        userId: _userSettings!.userId,
        emailNotifications: _userSettings!.emailNotifications,
        pushNotifications: _userSettings!.pushNotifications,
        taskReminders: _userSettings!.taskReminders,
        weeklyDigest: _userSettings!.weeklyDigest,
        theme: theme,
        language: _userSettings!.language,
        timezone: _userSettings!.timezone,
        dateFormat: _userSettings!.dateFormat,
        timeFormat: _userSettings!.timeFormat,
        createdAt: _userSettings!.createdAt,
        updatedAt: DateTime.now(),
      );
    });

    // Update app theme immediately
    TaskFlowApp.themeModeNotifier.value = theme == 'dark' 
        ? ThemeMode.dark 
        : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_userSettings != null)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userSettings == null
              ? const Center(child: Text('Failed to load settings'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNotificationSettings(),
                      const SizedBox(height: 24),
                      _buildAppearanceSettings(),
                      const SizedBox(height: 24),
                      _buildLanguageSettings(),
                      const SizedBox(height: 24),
                      _buildDateTimeSettings(),
                      const SizedBox(height: 24),
                      _buildDataSettings(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive notifications via email'),
              value: _userSettings!.emailNotifications,
              onChanged: (value) {
                setState(() {
                  _userSettings = UserSettings(
                    id: _userSettings!.id,
                    userId: _userSettings!.userId,
                    emailNotifications: value,
                    pushNotifications: _userSettings!.pushNotifications,
                    taskReminders: _userSettings!.taskReminders,
                    weeklyDigest: _userSettings!.weeklyDigest,
                    theme: _userSettings!.theme,
                    language: _userSettings!.language,
                    timezone: _userSettings!.timezone,
                    dateFormat: _userSettings!.dateFormat,
                    timeFormat: _userSettings!.timeFormat,
                    createdAt: _userSettings!.createdAt,
                    updatedAt: DateTime.now(),
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications'),
              value: _userSettings!.pushNotifications,
              onChanged: (value) {
                setState(() {
                  _userSettings = UserSettings(
                    id: _userSettings!.id,
                    userId: _userSettings!.userId,
                    emailNotifications: _userSettings!.emailNotifications,
                    pushNotifications: value,
                    taskReminders: _userSettings!.taskReminders,
                    weeklyDigest: _userSettings!.weeklyDigest,
                    theme: _userSettings!.theme,
                    language: _userSettings!.language,
                    timezone: _userSettings!.timezone,
                    dateFormat: _userSettings!.dateFormat,
                    timeFormat: _userSettings!.timeFormat,
                    createdAt: _userSettings!.createdAt,
                    updatedAt: DateTime.now(),
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('Task Reminders'),
              subtitle: const Text('Get reminded about upcoming tasks'),
              value: _userSettings!.taskReminders,
              onChanged: (value) {
                setState(() {
                  _userSettings = UserSettings(
                    id: _userSettings!.id,
                    userId: _userSettings!.userId,
                    emailNotifications: _userSettings!.emailNotifications,
                    pushNotifications: _userSettings!.pushNotifications,
                    taskReminders: value,
                    weeklyDigest: _userSettings!.weeklyDigest,
                    theme: _userSettings!.theme,
                    language: _userSettings!.language,
                    timezone: _userSettings!.timezone,
                    dateFormat: _userSettings!.dateFormat,
                    timeFormat: _userSettings!.timeFormat,
                    createdAt: _userSettings!.createdAt,
                    updatedAt: DateTime.now(),
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('Weekly Digest'),
              subtitle: const Text('Receive weekly summary emails'),
              value: _userSettings!.weeklyDigest,
              onChanged: (value) {
                setState(() {
                  _userSettings = UserSettings(
                    id: _userSettings!.id,
                    userId: _userSettings!.userId,
                    emailNotifications: _userSettings!.emailNotifications,
                    pushNotifications: _userSettings!.pushNotifications,
                    taskReminders: _userSettings!.taskReminders,
                    weeklyDigest: value,
                    theme: _userSettings!.theme,
                    language: _userSettings!.language,
                    timezone: _userSettings!.timezone,
                    dateFormat: _userSettings!.dateFormat,
                    timeFormat: _userSettings!.timeFormat,
                    createdAt: _userSettings!.createdAt,
                    updatedAt: DateTime.now(),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Theme'),
              subtitle: Text(_userSettings!.theme == 'dark' ? 'Dark Mode' : 'Light Mode'),
              trailing: DropdownButton<String>(
                value: _userSettings!.theme,
                items: const [
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _updateTheme(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Language & Region',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Language'),
              subtitle: Text(_userSettings!.language.toUpperCase()),
              trailing: DropdownButton<String>(
                value: _userSettings!.language,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'id', child: Text('Bahasa Indonesia')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _userSettings = UserSettings(
                        id: _userSettings!.id,
                        userId: _userSettings!.userId,
                        emailNotifications: _userSettings!.emailNotifications,
                        pushNotifications: _userSettings!.pushNotifications,
                        taskReminders: _userSettings!.taskReminders,
                        weeklyDigest: _userSettings!.weeklyDigest,
                        theme: _userSettings!.theme,
                        language: value,
                        timezone: _userSettings!.timezone,
                        dateFormat: _userSettings!.dateFormat,
                        timeFormat: _userSettings!.timeFormat,
                        createdAt: _userSettings!.createdAt,
                        updatedAt: DateTime.now(),
                      );
                    });
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Timezone'),
              subtitle: Text(_userSettings!.timezone),
              trailing: DropdownButton<String>(
                value: _userSettings!.timezone,
                items: const [
                  DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                  DropdownMenuItem(value: 'Asia/Jakarta', child: Text('Asia/Jakarta')),
                  DropdownMenuItem(value: 'America/New_York', child: Text('America/New_York')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _userSettings = UserSettings(
                        id: _userSettings!.id,
                        userId: _userSettings!.userId,
                        emailNotifications: _userSettings!.emailNotifications,
                        pushNotifications: _userSettings!.pushNotifications,
                        taskReminders: _userSettings!.taskReminders,
                        weeklyDigest: _userSettings!.weeklyDigest,
                        theme: _userSettings!.theme,
                        language: _userSettings!.language,
                        timezone: value,
                        dateFormat: _userSettings!.dateFormat,
                        timeFormat: _userSettings!.timeFormat,
                        createdAt: _userSettings!.createdAt,
                        updatedAt: DateTime.now(),
                      );
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date & Time Format',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date Format'),
              subtitle: Text(_userSettings!.dateFormat),
              trailing: DropdownButton<String>(
                value: _userSettings!.dateFormat,
                items: const [
                  DropdownMenuItem(value: 'DD/MM/YYYY', child: Text('DD/MM/YYYY')),
                  DropdownMenuItem(value: 'MM/DD/YYYY', child: Text('MM/DD/YYYY')),
                  DropdownMenuItem(value: 'YYYY-MM-DD', child: Text('YYYY-MM-DD')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _userSettings = UserSettings(
                        id: _userSettings!.id,
                        userId: _userSettings!.userId,
                        emailNotifications: _userSettings!.emailNotifications,
                        pushNotifications: _userSettings!.pushNotifications,
                        taskReminders: _userSettings!.taskReminders,
                        weeklyDigest: _userSettings!.weeklyDigest,
                        theme: _userSettings!.theme,
                        language: _userSettings!.language,
                        timezone: _userSettings!.timezone,
                        dateFormat: value,
                        timeFormat: _userSettings!.timeFormat,
                        createdAt: _userSettings!.createdAt,
                        updatedAt: DateTime.now(),
                      );
                    });
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Time Format'),
              subtitle: Text(_userSettings!.timeFormat),
              trailing: DropdownButton<String>(
                value: _userSettings!.timeFormat,
                items: const [
                  DropdownMenuItem(value: '24h', child: Text('24 Hour')),
                  DropdownMenuItem(value: '12h', child: Text('12 Hour')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _userSettings = UserSettings(
                        id: _userSettings!.id,
                        userId: _userSettings!.userId,
                        emailNotifications: _userSettings!.emailNotifications,
                        pushNotifications: _userSettings!.pushNotifications,
                        taskReminders: _userSettings!.taskReminders,
                        weeklyDigest: _userSettings!.weeklyDigest,
                        theme: _userSettings!.theme,
                        language: _userSettings!.language,
                        timezone: _userSettings!.timezone,
                        dateFormat: _userSettings!.dateFormat,
                        timeFormat: value,
                        createdAt: _userSettings!.createdAt,
                        updatedAt: DateTime.now(),
                      );
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data & Storage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Export Data'),
              subtitle: const Text('Download your data as JSON'),
              leading: const Icon(Icons.download),
              onTap: () {
                _safeContext.showSnackBar('Export feature coming soon!', Colors.blue);
              },
            ),
            ListTile(
              title: const Text('Clear Cache'),
              subtitle: const Text('Clear app cache and temporary files'),
              leading: const Icon(Icons.clear_all),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Cache'),
                    content: const Text('Are you sure you want to clear the app cache?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _safeContext.showSnackBar('Cache cleared!', Colors.green);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Delete Account'),
              subtitle: const Text('Permanently delete your account and data'),
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text(
                      'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _safeContext.showSnackBar('Account deletion feature coming soon!', Colors.red);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
