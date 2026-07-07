import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool notificationsEnabled = true;
  String selectedLanguage = 'Indonesia';

  /// Signs out and returns the user to the login screen.
  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: themeProvider.isDarkMode,
                  onChanged: themeProvider.toggleTheme,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notifikasi'),
                  value: notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      notificationsEnabled = value;
                    });
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedLanguage,
                    items: const [
                      DropdownMenuItem(
                        value: 'Indonesia',
                        child: Text('Indonesia'),
                      ),
                      DropdownMenuItem(
                        value: 'English',
                        child: Text('English'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedLanguage = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Bahasa'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              onPressed: _logout,
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}
