import 'dart:async';
import '../../domain/entities/notification_item.dart';
import '../../domain/failures/notification_failure.dart';
import '../../domain/repositories/i_notification_repository.dart';

class MockNotificationRepository implements INotificationRepository {
  final List<NotificationItem> _notifications = [];
  final StreamController<NotificationResult<List<NotificationItem>>> _controller = 
      StreamController<NotificationResult<List<NotificationItem>>>.broadcast();

  MockNotificationRepository() {
    // Seed with some initial mock notifications
    _notifications.addAll([
      NotificationItem(
        id: 'n1',
        title: 'Semester Registration',
        body: 'Registration for the 2026 academic session closes on Friday.',
        type: NotificationType.announcement,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationItem(
        id: 'n2',
        title: 'New Emergency Alert',
        body: 'Active SOS alert triggered near Senate Building.',
        type: NotificationType.emergency,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        isRead: false,
      ),
    ]);
    _controller.add(NotificationSuccess(List.unmodifiable(_notifications)));
  }

  @override
  Stream<NotificationResult<List<NotificationItem>>> streamNotifications() {
    final controller = StreamController<NotificationResult<List<NotificationItem>>>();
    controller.add(NotificationSuccess(List.unmodifiable(_notifications)));
    
    final subscription = _controller.stream.listen(
      (event) => controller.add(event),
      onError: (err) => controller.addError(err),
      onDone: () => controller.close(),
    );
    
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };
    
    return controller.stream;
  }

  @override
  Future<NotificationResult<void>> markAsRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _controller.add(NotificationSuccess(List.unmodifiable(_notifications)));
      return const NotificationSuccess(null);
    }
    return const NotificationFailed(NotificationStorageFailure('Notification not found'));
  }

  @override
  Future<NotificationResult<void>> addNotification(NotificationItem notification) async {
    _notifications.removeWhere((n) => n.id == notification.id);
    _notifications.insert(0, notification);
    _controller.add(NotificationSuccess(List.unmodifiable(_notifications)));
    return const NotificationSuccess(null);
  }

  void dispose() {
    _controller.close();
  }
}
