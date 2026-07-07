import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../widgets/app_page_route.dart';
import 'ticket_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  final String userId;
  final String role;

  const NotificationScreen({
    super.key,
    required this.userId,
    required this.role,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  /// Opens the related ticket detail for a notification.
  Future<void> _openTicket(Map<String, dynamic> notification) async {
    final ticketId = notification['ticket_id']?.toString();
    if (ticketId == null || ticketId.isEmpty) {
      return;
    }

    final ticket = await SupabaseService.fetchTicketById(ticketId);
    if (!mounted || ticket == null) {
      return;
    }

    await SupabaseService.markNotificationRead(notification['id'].toString());

    if (!mounted) return;
    Navigator.push(
      context,
      buildAppPageRoute(
        TicketDetailScreen(
          ticket: ticket.map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          ),
          role: widget.role,
          userId: widget.userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Notifikasi")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.watchNotifications(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.separated(
              padding: const EdgeInsets.all(15),
              itemCount: 4,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, _) => Container(
                height: 92,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? const [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.notifications_none, size: 56),
                  SizedBox(height: 12),
                  Text('Belum ada notifikasi.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];

              return InkWell(
                onTap: () => _openTicket(notif),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: notif['is_read'] == true
                        ? null
                        : Border.all(color: Colors.black12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        notif['is_read'] == true
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif['title']?.toString() ?? '-',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['message']?.toString() ?? '-',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif['created_at']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
