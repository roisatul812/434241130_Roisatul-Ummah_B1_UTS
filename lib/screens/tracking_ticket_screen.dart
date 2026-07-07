import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class TrackingTicketScreen extends StatelessWidget {
  final String ticketId;
  final String ticketTitle;

  const TrackingTicketScreen({
    super.key,
    required this.ticketId,
    required this.ticketTitle,
  });

  /// Formats ISO timestamps into a readable label.
  String _formatTime(String? value) {
    if (value == null) {
      return '-';
    }

    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) {
      return value;
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Converts the status code into a user-friendly label.
  String _statusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'open':
        return 'Open';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'closed':
        return 'Closed';
      default:
        return status ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking Tiket')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: SupabaseService.fetchTicketHistory(ticketId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final history = snapshot.data ?? [];

            if (history.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timeline, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      ticketTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Belum ada riwayat status untuk tiket ini.'),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final isLast = index == history.length - 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 70,
                            color: Colors.grey.shade400,
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_statusLabel(item['old_status']?.toString())} → ${_statusLabel(item['new_status']?.toString())}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Diubah oleh: ${item['changed_by_name'] ?? '-'}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(item['changed_at']?.toString()),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
