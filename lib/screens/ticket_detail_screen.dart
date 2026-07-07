import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/supabase_service.dart';
import 'tracking_ticket_screen.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, String> ticket;
  final String role;
  final String userId;

  const TicketDetailScreen({
    super.key,
    required this.ticket,
    required this.role,
    required this.userId,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late String status;
  late String assignedTo;
  final TextEditingController _commentController = TextEditingController();
  bool _isSaving = false;
  bool _isCommenting = false;

  /// Applies alpha to a color without deprecated opacity helpers.
  Color _alphaColor(Color color, double alpha) {
    return Color.fromARGB(
      (alpha * 255).round(),
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
    );
  }

  String get ticketId => widget.ticket['id'] ?? '';

  @override
  void initState() {
    super.initState();
    status = (widget.ticket["status"] ?? "open").toLowerCase();
    assignedTo = widget.ticket["assignedTo"] ?? "-";
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "open":
        return Colors.red.shade300;
      case "assigned":
        return Colors.blue.shade300;
      case "in_progress":
        return Colors.orange.shade300;
      case "closed":
        return Colors.green.shade300;
      default:
        return Colors.grey;
    }
  }

  String getStatusLabel(String status) {
    switch (status) {
      case "open":
        return "Open";
      case "assigned":
        return "Assigned";
      case "in_progress":
        return "In Progress";
      case "closed":
        return "Closed";
      default:
        return status;
    }
  }

  /// Persists the ticket status or assignment changes.
  Future<void> updateTicket() async {
    setState(() {
      _isSaving = true;
    });

    try {
      if (ticketId.isNotEmpty) {
        await SupabaseService.updateTicket(
          ticketId: ticketId,
          status: status,
          assignedTo: widget.role == 'admin' && assignedTo != '-'
              ? assignedTo
              : null,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tiket berhasil diperbarui")),
      );
      Navigator.pop(context, {
        ...widget.ticket,
        'status': status,
        'assignedTo': assignedTo,
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui tiket: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Adds a comment and refreshes the realtime comments stream.
  Future<void> _submitComment() async {
    if (ticketId.isEmpty || _commentController.text.trim().isEmpty) {
      return;
    }

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _isCommenting = true;
    });

    try {
      await SupabaseService.addComment(
        ticketId: ticketId,
        userId: currentUser.id,
        comment: _commentController.text,
      );
      _commentController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isCommenting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Detail Tiket")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.ticket["title"] ?? "-",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Text(
            "${widget.ticket["date"]} • ${widget.ticket["priority"]}",
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 15),

          // STATUS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _alphaColor(getStatusColor(status), isDark ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              getStatusLabel(status),
              style: TextStyle(
                color: getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: ticketId.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrackingTicketScreen(
                            ticketId: ticketId,
                            ticketTitle: widget.ticket["title"] ?? "Ticket",
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.timeline),
              label: const Text('Lihat Tracking Tiket'),
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            "Deskripsi",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.ticket["description"] ?? "Tidak ada deskripsi"),
          ),

          // LAMPIRAN GAMBAR (kalau ada)
          if ((widget.ticket["attachment_url"] ?? "").isNotEmpty) ...[
            const SizedBox(height: 25),
            const Text(
              "Lampiran",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.ticket["attachment_url"]!,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    color: Theme.of(context).cardColor,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Gagal memuat gambar'),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 25),

          const Text('Komentar', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (ticketId.isEmpty)
            const Text(
              'Komentar akan aktif setelah tiket tersimpan di Supabase.',
            ),
          if (ticketId.isNotEmpty)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.watchComments(ticketId),
              builder: (context, snapshot) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: SupabaseService.fetchComments(ticketId),
                  builder: (context, commentsSnapshot) {
                    final comments = commentsSnapshot.data ?? [];

                    if (commentsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (comments.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Belum ada komentar.'),
                      );
                    }

                    return Column(
                      children: comments.map((comment) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (comment['user_name'] ?? 'User').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(comment['comment']?.toString() ?? '-'),
                              const SizedBox(height: 6),
                              Text(
                                comment['created_at']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),

          const SizedBox(height: 10),

          if (ticketId.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Tulis komentar...',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCommenting ? null : _submitComment,
                    child: _isCommenting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirim'),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 25),

          // ADMIN & HELPDESK ONLY
          if (widget.role == "admin" || widget.role == "helpdesk") ...[
            const Text(
              "Update Status",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: status,
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                DropdownMenuItem(
                  value: 'in_progress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) {
                setState(() {
                  status = value!;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ADMIN ONLY: assign tiket ke helpdesk
            if (widget.role == "admin") ...[
              const Text(
                "Assign To",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              FutureBuilder<List<AppUser>>(
                future: SupabaseService.fetchHelpdeskUsers(),
                builder: (context, snapshot) {
                  final helpdeskUsers = snapshot.data ?? [];

                  // Pastikan value assignedTo yang sedang aktif masih ada
                  // di daftar, supaya dropdown tidak error kalau
                  // assignedTo == "-" atau user sudah tidak aktif.
                  final validIds = helpdeskUsers.map((u) => u.id).toSet();
                  final currentValue = validIds.contains(assignedTo)
                      ? assignedTo
                      : null;

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: currentValue,
                    hint: const Text("Pilih user"),
                    items: helpdeskUsers.map((user) {
                      return DropdownMenuItem(
                        value: user.id,
                        child: Text(user.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        assignedTo = value!;
                        // Begitu tiket di-assign ke helpdesk, status
                        // otomatis ikut berubah jadi "assigned".
                        status = 'assigned';
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                ),
                onPressed: _isSaving ? null : updateTicket,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Simpan Perubahan"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}