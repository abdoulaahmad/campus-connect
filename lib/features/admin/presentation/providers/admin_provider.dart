import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/admin_event.dart';
import '../../domain/entities/admin_announcement.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/failures/admin_failure.dart';
import '../../domain/repositories/i_admin_repository.dart';
import '../../../../core/providers/core_providers.dart';

class AdminDashboardState {
  final List<User> users;
  final List<AdminEvent> events;
  final List<AdminAnnouncement> announcements;
  final bool isLoading;
  final String? error;

  const AdminDashboardState({
    this.users = const [],
    this.events = const [],
    this.announcements = const [],
    this.isLoading = false,
    this.error,
  });

  AdminDashboardState copyWith({
    List<User>? users,
    List<AdminEvent>? events,
    List<AdminAnnouncement>? announcements,
    bool? isLoading,
    String? error,
  }) {
    return AdminDashboardState(
      users: users ?? this.users,
      events: events ?? this.events,
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminDashboardNotifier extends StateNotifier<AdminDashboardState> {
  final IAdminRepository _adminRepository;

  AdminDashboardNotifier(this._adminRepository) : super(const AdminDashboardState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    
    final usersResult = await _adminRepository.getUsers();
    final eventsResult = await _adminRepository.getEvents();
    final annResult = await _adminRepository.getAnnouncements();

    List<User> users = [];
    List<AdminEvent> events = [];
    List<AdminAnnouncement> announcements = [];
    String? errorMsg;

    if (usersResult is AdminSuccess<List<User>>) {
      users = usersResult.value;
    } else if (usersResult is AdminFailed<List<User>>) {
      errorMsg = usersResult.failure.message;
    }

    if (eventsResult is AdminSuccess<List<AdminEvent>>) {
      events = eventsResult.value;
    } else if (eventsResult is AdminFailed<List<AdminEvent>>) {
      errorMsg ??= eventsResult.failure.message;
    }

    if (annResult is AdminSuccess<List<AdminAnnouncement>>) {
      announcements = annResult.value;
    } else if (annResult is AdminFailed<List<AdminAnnouncement>>) {
      errorMsg ??= annResult.failure.message;
    }

    state = state.copyWith(
      isLoading: false,
      users: users,
      events: events,
      announcements: announcements,
      error: errorMsg,
    );
  }

  Future<bool> updateUserRole(String userId, String role) async {
    final result = await _adminRepository.updateUserRole(userId, role);
    if (result is AdminSuccess<void>) {
      await loadAll();
      return true;
    } else if (result is AdminFailed<void>) {
      state = state.copyWith(error: result.failure.message);
      return false;
    }
    return false;
  }

  Future<bool> createEvent({
    required String title,
    required String description,
    required String venue,
    required DateTime timestamp,
  }) async {
    final event = AdminEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      venue: venue,
      timestamp: timestamp,
    );
    final result = await _adminRepository.createEvent(event);
    if (result is AdminSuccess<void>) {
      await loadAll();
      return true;
    } else if (result is AdminFailed<void>) {
      state = state.copyWith(error: result.failure.message);
      return false;
    }
    return false;
  }

  Future<bool> createAnnouncement({
    required String title,
    required String content,
  }) async {
    final announcement = AdminAnnouncement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      timestamp: DateTime.now(),
    );
    final result = await _adminRepository.createAnnouncement(announcement);
    if (result is AdminSuccess<void>) {
      await loadAll();
      return true;
    } else if (result is AdminFailed<void>) {
      state = state.copyWith(error: result.failure.message);
      return false;
    }
    return false;
  }
}

final adminDashboardProvider = StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return AdminDashboardNotifier(repository);
});
