import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'ticket_list_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import '../services/supabase_service.dart';

class MainNavigation extends StatefulWidget {
  final String role;
  final String email;
  final String userId;

  const MainNavigation({
    super.key,
    required this.role,
    required this.email,
    required this.userId,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  Stream<List<Map<String, dynamic>>> _notificationStream() {
    return SupabaseService.watchNotifications(widget.userId);
  }

  List<_NavigationItem> get _items {
    switch (widget.role) {
      case 'admin':
        return const [
          _NavigationItem(Icons.dashboard, 'Dashboard'),
          _NavigationItem(Icons.confirmation_number, 'Tiket'),
          _NavigationItem(Icons.notifications, 'Notif'),
          _NavigationItem(Icons.person, 'Profile'),
        ];
      case 'helpdesk':
        return const [
          _NavigationItem(Icons.dashboard, 'Dashboard'),
          _NavigationItem(Icons.assignment_turned_in, 'Assigned'),
          _NavigationItem(Icons.notifications, 'Notif'),
          _NavigationItem(Icons.person, 'Profile'),
        ];
      case 'user':
      default:
        return const [
          _NavigationItem(Icons.dashboard, 'Dashboard'),
          _NavigationItem(Icons.confirmation_number, 'Tiket'),
          _NavigationItem(Icons.notifications, 'Notif'),
          _NavigationItem(Icons.person, 'Profile'),
        ];
    }
  }

  List<Widget> _buildScreens() {
    switch (widget.role) {
      case 'admin':
        return [
          DashboardScreen(role: widget.role, userId: widget.userId),
          TicketListScreen(role: widget.role, userId: widget.userId),
          NotificationScreen(userId: widget.userId, role: widget.role),
          ProfileScreen(role: widget.role, email: widget.email),
        ];
      case 'helpdesk':
        return [
          DashboardScreen(role: widget.role, userId: widget.userId),
          TicketListScreen(role: widget.role, userId: widget.userId),
          NotificationScreen(userId: widget.userId, role: widget.role),
          ProfileScreen(role: widget.role, email: widget.email),
        ];
      case 'user':
      default:
        return [
          DashboardScreen(role: widget.role, userId: widget.userId),
          TicketListScreen(role: widget.role, userId: widget.userId),
          NotificationScreen(userId: widget.userId, role: widget.role),
          ProfileScreen(role: widget.role, email: widget.email),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final items = _items;

    return Scaffold(
      body: screens[currentIndex],

      bottomNavigationBar: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationStream(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data == null
              ? 0
              : snapshot.data!.where((item) => item['is_read'] != true).length;

          return BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            items: items.map((item) {
              final isNotificationTab = item.label == 'Notif';

              return BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(item.icon),
                    if (isNotificationTab && unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                label: item.label,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String label;

  const _NavigationItem(this.icon, this.label);
}
