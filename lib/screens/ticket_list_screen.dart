import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/app_page_route.dart';
import 'ticket_detail_screen.dart';

class TicketListScreen extends StatefulWidget {
  final String role;
  final String userId;

  const TicketListScreen({super.key, required this.role, required this.userId});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  late Future<List<Map<String, dynamic>>> _ticketsFuture;

  /// Applies alpha to a color without deprecated opacity helpers.
  Color _alphaColor(Color color, double alpha) {
    return Color.fromARGB(
      (alpha * 255).round(),
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
    );
  }

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _loadTickets();
  }

  /// Loads tickets for the current signed-in user.
  Future<List<Map<String, dynamic>>> _loadTickets() async {
    final profile = await SupabaseService.fetchCurrentProfile();
    if (profile == null) {
      return [];
    }

    return SupabaseService.fetchTicketsForUser(profile);
  }

  /// Returns a user-friendly status label.
  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Open';
      case 'assigned':
        return 'Assign';
      case 'in_progress':
        return 'In Progress';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  /// Returns a semantic color for the ticket status.
  Color _statusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.red;
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Builds a loading skeleton for ticket cards.
  Widget _buildSkeletonCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 18,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 12,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 22,
              width: 88,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a friendly empty state when no tickets exist.
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Belum ada tiket',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Tiket akan muncul di sini setelah dibuat atau di-assign.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("List Tiket")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (context, index) => _buildSkeletonCard(context),
            );
          }

          final tickets = snapshot.data ?? [];
          if (tickets.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _ticketsFuture = _loadTickets();
              });
              await _ticketsFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final status = (ticket['status'] ?? 'open').toString();

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      buildAppPageRoute(
                        TicketDetailScreen(
                          ticket: ticket.map(
                            (key, value) =>
                                MapEntry(key, value?.toString() ?? ''),
                          ),
                          role: widget.role,
                          userId: widget.userId,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket['title']?.toString() ?? '-',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "${ticket['created_at']?.toString() ?? '-'} • ${ticket['priority']?.toString() ?? '-'}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _statusBadge(context, status),

                          const SizedBox(height: 8),

                          if (widget.role == "admin")
                            Text(
                              "Assigned to: ${ticket['assigned_to']?.toString() ?? '-'}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),

                          if (widget.role == "helpdesk")
                            Text(
                              "Assigned to you",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),

                          const SizedBox(height: 6),

                          Text(
                            widget.role == "admin"
                                ? "Tap untuk mengelola tiket"
                                : "Tap untuk melihat detail",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
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

  Widget _statusBadge(BuildContext context, String status) {
    final color = _statusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _alphaColor(color, 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _alphaColor(color, 0.28)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
