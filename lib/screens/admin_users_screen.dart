import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/supabase_service.dart';

class AdminUsersScreen extends StatefulWidget {
  final String userId;

  const AdminUsersScreen({super.key, required this.userId});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<AppUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = SupabaseService.fetchAllUsers();
  }

  /// Reloads the user list after an admin action.
  Future<void> _refreshUsers() async {
    setState(() {
      _usersFuture = SupabaseService.fetchAllUsers();
    });
    await _usersFuture;
  }

  /// Toggles whether a user account is active.
  Future<void> _toggleActive(AppUser user, bool active) async {
    await SupabaseService.setUserActive(user.id, active);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${user.name} ${active ? 'diaktifkan' : 'dinonaktifkan'}',
        ),
      ),
    );
    await _refreshUsers();
  }

  /// Returns a readable role label.
  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.helpdesk:
        return 'Helpdesk';
      case UserRole.user:
        return 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola User')),
      body: FutureBuilder<List<AppUser>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data ?? const [];

          if (users.isEmpty) {
            return const Center(child: Text('Belum ada user yang terdaftar.'));
          }

          return RefreshIndicator(
            onRefresh: _refreshUsers,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = users[index];

                return Card(
                  elevation: 3,
                  shadowColor: Colors.black26,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(user.name.isEmpty ? user.email : user.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(user.email),
                        const SizedBox(height: 4),
                        Text(_roleLabel(user.role)),
                      ],
                    ),
                    trailing: Switch(
                      value: user.isActive,
                      onChanged: (value) => _toggleActive(user, value),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
