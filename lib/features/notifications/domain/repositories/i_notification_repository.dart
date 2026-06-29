import '../entities/notification_item.dart';
import '../failures/notification_failure.dart';

abstract class INotificationRepository {
  Stream<NotificationResult<List<NotificationItem>>> streamNotifications();
  Future<NotificationResult<void>> markAsRead(String notificationId);
  Future<NotificationResult<void>> addNotification(NotificationItem notification);
}
