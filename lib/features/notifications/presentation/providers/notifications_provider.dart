import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/failures/notification_failure.dart';
import '../../domain/repositories/i_notification_repository.dart';
import '../../../../core/providers/core_providers.dart';

final notificationsProvider = StreamProvider<List<NotificationItem>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.streamNotifications().map((result) {
    if (result is NotificationSuccess<List<NotificationItem>>) {
      return result.value;
    } else {
      return [];
    }
  });
});

class NotificationNotifier extends StateNotifier<AsyncValue<void>> {
  final INotificationRepository _repository;

  NotificationNotifier(this._repository) : super(const AsyncData(null));

  Future<void> markAsRead(String notificationId) async {
    state = const AsyncLoading();
    final result = await _repository.markAsRead(notificationId);
    if (result is NotificationSuccess<void>) {
      state = const AsyncData(null);
    } else if (result is NotificationFailed<void>) {
      state = AsyncError((result as NotificationFailed).failure.message, StackTrace.current);
    }
  }

  Future<void> addNotification(NotificationItem item) async {
    state = const AsyncLoading();
    final result = await _repository.addNotification(item);
    if (result is NotificationSuccess<void>) {
      state = const AsyncData(null);
    } else if (result is NotificationFailed<void>) {
      state = AsyncError((result as NotificationFailed).failure.message, StackTrace.current);
    }
  }
}

final notificationActionProvider = StateNotifierProvider<NotificationNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationNotifier(repository);
});
