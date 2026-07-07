import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../config/supabase_config.dart';
import '../models/app_user.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static bool get isReady => SupabaseConfig.isConfigured;

  /// Signs in an existing account with Supabase Auth.
  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates a new Supabase Auth user and stores the profile metadata.
  static Future<AuthResponse> signUpWithName({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.user,
  }) {
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim(), 'role': role.value},
    );
  }

  /// Sends a reset password email through Supabase Auth.
  static Future<void> resetPasswordForEmail(String email) {
    return client.auth.resetPasswordForEmail(email.trim());
  }

  /// Signs out the current user session.
  static Future<void> signOut() {
    return client.auth.signOut();
  }

  /// Returns the profile row that matches the current authenticated user.
  static Future<AppUser?> fetchCurrentProfile() async {
    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      return null;
    }

    return fetchProfileById(currentUser.id);
  }

  /// Returns a profile row by id from the public users table.
  static Future<AppUser?> fetchProfileById(String id) async {
    final result = await client
        .from('users')
        .select('id,name,email,role,is_active,created_at')
        .eq('id', id)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    return AppUser.fromMap(result);
  }

  /// Returns tickets filtered by the current user's role.
  static Future<List<Map<String, dynamic>>> fetchTicketsForUser(
    AppUser user,
  ) async {
    dynamic query = client.from('tickets').select('*');

    if (user.role == UserRole.user) {
      query = query.eq('created_by', user.id);
    } else if (user.role == UserRole.helpdesk) {
      query = query.eq('assigned_to', user.id);
    }

    final result = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result as List<dynamic>);
  }

  /// Returns a single ticket row by id.
  static Future<Map<String, dynamic>?> fetchTicketById(String ticketId) async {
    final result = await client
        .from('tickets')
        .select('*')
        .eq('id', ticketId)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    return Map<String, dynamic>.from(result);
  }

  /// Creates a new ticket for the authenticated user.
  static Future<Map<String, dynamic>> createTicket({
    required String title,
    required String description,
    required String priority,
    required String createdBy,
    String? attachmentUrl,
  }) async {
    final result = await client
        .from('tickets')
        .insert({
          'title': title.trim(),
          'description': description.trim(),
          'priority': priority,
          'status': 'open',
          'created_by': createdBy,
          'attachment_url': attachmentUrl,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(result);
  }

  /// Uploads an attachment to Supabase Storage and returns a public URL.
  static Future<String> uploadTicketAttachment({
    required XFile file,
    required String userId,
  }) async {
    final bytes = await file.readAsBytes();
    final extension = file.name.split('.').last.toLowerCase();
    final contentType = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    final storagePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await client.storage
        .from('ticket-attachments')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return client.storage.from('ticket-attachments').getPublicUrl(storagePath);
  }

  /// Updates the ticket status and optionally assigns the ticket.
  static Future<Map<String, dynamic>> updateTicket({
    required String ticketId,
    String? status,
    String? assignedTo,
  }) async {
    final payload = <String, dynamic>{};

    if (status != null) {
      payload['status'] = status;
    }

    if (assignedTo != null) {
      payload['assigned_to'] = assignedTo;
    }

    final result = await client
        .from('tickets')
        .update(payload)
        .eq('id', ticketId)
        .select()
        .single();

    return Map<String, dynamic>.from(result);
  }

  /// Returns comments for a ticket with the author name included.
  static Future<List<Map<String, dynamic>>> fetchComments(
    String ticketId,
  ) async {
    final result = await client
        .from('ticket_comments')
        .select('id,ticket_id,user_id,comment,created_at,users(name)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(result as List<dynamic>).map((row) {
      final author = row['users'];
      return {
        ...row,
        'user_name': author is Map<String, dynamic>
            ? author['name']
            : row['user_id'],
      };
    }).toList();
  }

  /// Adds a new comment to a ticket.
  static Future<Map<String, dynamic>> addComment({
    required String ticketId,
    required String userId,
    required String comment,
  }) async {
    final result = await client
        .from('ticket_comments')
        .insert({
          'ticket_id': ticketId,
          'user_id': userId,
          'comment': comment.trim(),
        })
        .select()
        .single();

    return Map<String, dynamic>.from(result);
  }

  /// Streams comments for a ticket in realtime.
  static Stream<List<Map<String, dynamic>>> watchComments(String ticketId) {
    return client
        .from('ticket_comments')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at');
  }

  /// Returns ticket history entries with the editor name included.
  static Future<List<Map<String, dynamic>>> fetchTicketHistory(
    String ticketId,
  ) async {
    final result = await client
        .from('ticket_history')
        .select(
          'id,ticket_id,old_status,new_status,changed_by,changed_at,users(name)',
        )
        .eq('ticket_id', ticketId)
        .order('changed_at', ascending: true);

    return List<Map<String, dynamic>>.from(result as List<dynamic>).map((row) {
      final editor = row['users'];
      return {
        ...row,
        'changed_by_name': editor is Map<String, dynamic>
            ? editor['name']
            : row['changed_by'],
      };
    }).toList();
  }

  /// Returns helpdesk users for ticket assignment.
  static Future<List<AppUser>> fetchHelpdeskUsers() async {
    final result = await client
        .from('users')
        .select('id,name,email,role,is_active,created_at')
        .eq('role', 'helpdesk')
        .eq('is_active', true)
        .order('name');

    return List<Map<String, dynamic>>.from(
      result as List<dynamic>,
    ).map(AppUser.fromMap).toList();
  }

  /// Returns all user profiles for admin management.
  static Future<List<AppUser>> fetchAllUsers() async {
    final result = await client
        .from('users')
        .select('id,name,email,role,is_active,created_at')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(
      result as List<dynamic>,
    ).map(AppUser.fromMap).toList();
  }

  /// Updates whether a user is active.
  static Future<void> setUserActive(String userId, bool isActive) async {
    await client.from('users').update({'is_active': isActive}).eq('id', userId);
  }

  /// Streams notifications for the signed-in user in realtime.
  static Stream<List<Map<String, dynamic>>> watchNotifications(String userId) {
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  /// Returns the current notification rows for a user.
  static Future<List<Map<String, dynamic>>> fetchNotifications(
    String userId,
  ) async {
    final result = await client
        .from('notifications')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(result as List<dynamic>);
  }

  /// Counts unread notifications for a user.
  static Future<int> fetchUnreadNotificationCount(String userId) async {
    final notifications = await fetchNotifications(userId);
    return notifications.where((item) => item['is_read'] != true).length;
  }

  /// Marks every notification for a user as read.
  static Future<void> markAllNotificationsRead(String userId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Marks a notification as read.
  static Future<void> markNotificationRead(String notificationId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Counts tickets grouped by status for dashboard widgets.
  static Future<Map<String, int>> countTicketsByStatus(AppUser user) async {
    final tickets = await fetchTicketsForUser(user);
    final counts = <String, int>{
      'total': tickets.length,
      'open': 0,
      'assigned': 0,
      'in_progress': 0,
      'closed': 0,
    };

    for (final ticket in tickets) {
      final status = (ticket['status'] ?? 'open').toString();
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }
}
