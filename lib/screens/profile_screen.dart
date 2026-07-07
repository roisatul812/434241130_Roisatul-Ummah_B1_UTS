import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'setting_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String role;
  final String? email;

  const ProfileScreen({super.key, required this.role, required this.email});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fallback kalau profile belum sempat ke-fetch / null.
    final displayEmail = (email == null || email!.isEmpty)
        ? "user@mail.com"
        : email!;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<AppUser?>(
          future: SupabaseService.fetchCurrentProfile(),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final displayName = profile?.name ?? "-";

            return Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 40),
                ),

                const SizedBox(height: 15),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),

                const SizedBox(height: 5),

                Text(
                  profile?.email ?? displayEmail,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text("Settings"),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingScreen(),
                            ),
                          );
                        },
                      ),

                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.lock),
                        title: const Text("Change Password"),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // LOGOUT BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await SupabaseService.signOut();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text("Logout"),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}