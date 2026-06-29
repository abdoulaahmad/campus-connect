import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/notification_item.dart';
import '../../domain/failures/notification_failure.dart';
import '../../domain/repositories/i_notification_repository.dart';

/// Production [INotificationRepository] backed by Supabase Postgres + Realtime.
///
/// Table: `notifications`
/// Columns: id (text pk), user_id (text), title (text), body (text),
///          type (text), is_read (bool), created_at (timestamptz)
///
/// Row-level security must allow each user to read only their own rows:
///   auth.uid()::text = user_id
class SupabaseNotificationRepository implements INotificationRepository {
  SupabaseNotificationRepository({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  static const _table = 'notifications';

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Stream<NotificationResult<List<NotificationItem>>> streamNotifications() {
    final controller =
        StreamController<NotificationResult<List<NotificationItem>>>();

    Future<void> fetch() async {
      final uid = _userId;
      if (uid == null) {
        if (!controller.isClosed) {
          controller.add(NotificationSuccess(const []));
        }
        return;
      }
      try {
        final data = await _client
            .from(_table)
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false);

        final items = (data as List<dynamic>)
            .map((e) => _fromRow(e as Map<String, dynamic>))
            .toList();

        if (!controller.isClosed) {
          controller.add(NotificationSuccess(items));
        }
      } on sb.PostgrestException catch (e) {
        if (!controller.isClosed) {
          controller.add(
            NotificationFailed(NotificationStorageFailure(e.message)),
          );
        }
      } catch (_) {
        if (!controller.isClosed) {
          controller.add(
            const NotificationFailed(NotificationStorageFailure()),
          );
        }
      }
    }

    fetch();

    final uid = _userId;
    final channel = _client
        .channel('notifications:${uid ?? "anon"}')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          filter: uid != null
              ? sb.PostgresChangeFilter(
                  type: sb.PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: uid,
                )
              : null,
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<NotificationResult<void>> markAsRead(String notificationId) async {
    try {
      await _client
          .from(_table)
          .update({'is_read': true})
          .eq('id', notificationId);
      return const NotificationSuccess(null);
    } on sb.PostgrestException catch (e) {
      return NotificationFailed(NotificationStorageFailure(e.message));
    } catch (_) {
      return const NotificationFailed(NotificationStorageFailure());
    }
  }

  @override
  Future<NotificationResult<void>> addNotification(
    NotificationItem notification,
  ) async {
    final uid = _userId;
    if (uid == null) {
      return const NotificationFailed(
        NotificationStorageFailure('No authenticated user'),
      );
    }
    try {
      await _client.from(_table).upsert({
        'id': notification.id,
        'user_id': uid,
        'title': notification.title,
        'body': notification.body,
        'type': notification.type.name,
        'is_read': notification.isRead,
        'created_at': notification.createdAt.toUtc().toIso8601String(),
      });
      return const NotificationSuccess(null);
    } on sb.PostgrestException catch (e) {
      return NotificationFailed(NotificationStorageFailure(e.message));
    } catch (_) {
      return const NotificationFailed(NotificationStorageFailure());
    }
  }

  // ── Private helper ─────────────────────────────────────────────────────────

  NotificationItem _fromRow(Map<String, dynamic> row) {
    return NotificationItem(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      type: NotificationType.values.firstWhere(
        (t) => t.name == (row['type'] as String? ?? ''),
        orElse: () => NotificationType.announcement,
      ),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      isRead: row['is_read'] as bool? ?? false,
    );
  }
}
