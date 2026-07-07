import 'package:flutter/material.dart';
import 'admin_users_screen.dart';
import 'ticket_list_screen.dart';
import 'create_ticket_screen.dart';

import '../models/app_user.dart';
import '../services/supabase_service.dart';
import '../widgets/app_page_route.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  final String userId;

  const DashboardScreen({super.key, required this.role, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  /// Loads dashboard counts for the current role scope.
  Future<Map<String, int>> _loadStats() {
    return SupabaseService.countTicketsByStatus(
      AppUser(
        id: widget.userId,
        name: '',
        email: '',
        role: UserRoleX.fromValue(widget.role),
      ),
    );
  }

  /// Builds a metric card with a label and value.
  Widget _statCard(BuildContext context, String title, int value) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }

  /// Builds a themed menu button.
  Widget _menuButton(BuildContext context, String title, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Dashboard (${widget.role.toUpperCase()})")),
      body: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final counts = snapshot.data ?? const <String, int>{};

          if (snapshot.connectionState == ConnectionState.waiting) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    height: 24,
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _statCard(context, '...', 0)),
                      const SizedBox(width: 10),
                      Expanded(child: _statCard(context, '...', 0)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _statCard(context, '...', 0)),
                      const SizedBox(width: 10),
                      Expanded(child: _statCard(context, '...', 0)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _statCard(context, '...', 0),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _statCard(context, "Total", counts['total'] ?? 0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(context, "Open", counts['open'] ?? 0),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        context,
                        "Assign",
                        counts['assigned'] ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        context,
                        "In Progress",
                        counts['in_progress'] ?? 0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Dibungkus SizedBox lebar penuh supaya card "Closed"
                // tidak shrink-wrap kecil, melainkan selebar card lainnya.
                SizedBox(
                  width: double.infinity,
                  child: _statCard(
                    context,
                    "Closed",
                    counts['closed'] ?? 0,
                  ),
                ),

                const SizedBox(height: 25),

                Text(
                  "Menu",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),

                const SizedBox(height: 15),

                if (widget.role == "admin") ...[
                  _menuButton(context, "Manage Tiket", () {
                    Navigator.push(
                      context,
                      buildAppPageRoute(
                        TicketListScreen(
                          role: widget.role,
                          userId: widget.userId,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  _menuButton(context, "Assign Tiket", () {
                    Navigator.push(
                      context,
                      buildAppPageRoute(
                        TicketListScreen(
                          role: widget.role,
                          userId: widget.userId,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  _menuButton(context, "Kelola User", () {
                    Navigator.push(
                      context,
                      buildAppPageRoute(
                        AdminUsersScreen(userId: widget.userId),
                      ),
                    );
                  }),
                ] else ...[
                  _menuButton(context, "List Tiket", () {
                    Navigator.push(
                      context,
                      buildAppPageRoute(
                        TicketListScreen(
                          role: widget.role,
                          userId: widget.userId,
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  _menuButton(context, "Create Tiket", () {
                    Navigator.push(
                      context,
                      buildAppPageRoute(const CreateTicketScreen()),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}