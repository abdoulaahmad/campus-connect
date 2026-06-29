import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin/domain/entities/admin_event.dart';
import '../../../admin/domain/entities/admin_announcement.dart';
import '../../../admin/domain/failures/admin_failure.dart';
import '../../../../core/providers/core_providers.dart';

class HomeState {
  final List<AdminEvent> events;
  final List<AdminAnnouncement> announcements;
  final bool isLoading;

  const HomeState({
    this.events = const [],
    this.announcements = const [],
    this.isLoading = false,
  });

  HomeState copyWith({
    List<AdminEvent>? events,
    List<AdminAnnouncement>? announcements,
    bool? isLoading,
  }) {
    return HomeState(
      events: events ?? this.events,
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final Ref _ref;

  HomeNotifier(this._ref) : super(const HomeState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final adminRepo = _ref.read(adminRepositoryProvider);
    
    final eventsRes = await adminRepo.getEvents();
    final annRes = await adminRepo.getAnnouncements();

    List<AdminEvent> events = [];
    List<AdminAnnouncement> announcements = [];

    if (eventsRes is AdminSuccess<List<AdminEvent>>) {
      events = eventsRes.value;
    }
    if (annRes is AdminSuccess<List<AdminAnnouncement>>) {
      announcements = annRes.value;
    }

    state = HomeState(
      events: events,
      announcements: announcements,
      isLoading: false,
    );
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref);
});
