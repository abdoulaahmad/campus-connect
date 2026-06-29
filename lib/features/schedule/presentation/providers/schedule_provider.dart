import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/schedule.dart';
import '../../domain/failures/schedule_failure.dart';
import '../../domain/repositories/i_schedule_repository.dart';
import '../../../../core/providers/core_providers.dart';

class ScheduleEditState {
  final Map<String, String> dailyBitmasks;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? successMessage;

  const ScheduleEditState({
    this.dailyBitmasks = const {},
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.successMessage,
  });

  ScheduleEditState copyWith({
    Map<String, String>? dailyBitmasks,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? successMessage,
  }) {
    return ScheduleEditState(
      dailyBitmasks: dailyBitmasks ?? this.dailyBitmasks,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      successMessage: successMessage,
    );
  }
}

class ScheduleEditNotifier extends StateNotifier<ScheduleEditState> {
  final IScheduleRepository _repository;
  final String _userId;

  ScheduleEditNotifier(this._repository, this._userId) : super(const ScheduleEditState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final result = await _repository.getSchedule(_userId);
    if (result is ScheduleSuccess<Schedule>) {
      state = state.copyWith(
        isLoading: false,
        dailyBitmasks: result.value.dailyBitmasks,
      );
    } else if (result is ScheduleFailed<Schedule>) {
      state = state.copyWith(
        isLoading: false,
        error: result.failure.message,
      );
    }
  }

  void toggleSlot(String day, int index) {
    final currentMask = state.dailyBitmasks[day] ?? '0' * 48;
    if (index < 0 || index >= 48) return;
    
    final char = currentMask[index] == '1' ? '0' : '1';
    final newMask = currentMask.substring(0, index) + char + currentMask.substring(index + 1);
    
    final newMasks = Map<String, String>.from(state.dailyBitmasks);
    newMasks[day] = newMask;
    
    state = state.copyWith(dailyBitmasks: newMasks);
  }

  void setSlot(String day, int index, bool value) {
    final currentMask = state.dailyBitmasks[day] ?? '0' * 48;
    if (index < 0 || index >= 48) return;
    
    final char = value ? '1' : '0';
    final newMask = currentMask.substring(0, index) + char + currentMask.substring(index + 1);
    
    final newMasks = Map<String, String>.from(state.dailyBitmasks);
    newMasks[day] = newMask;
    
    state = state.copyWith(dailyBitmasks: newMasks);
  }

  Future<bool> save() async {
    state = state.copyWith(isSaving: true);
    final schedule = Schedule(userId: _userId, dailyBitmasks: state.dailyBitmasks);
    final result = await _repository.updateSchedule(schedule);
    
    if (result is ScheduleSuccess<void>) {
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Schedule saved successfully!',
      );
      return true;
    } else if (result is ScheduleFailed<void>) {
      state = state.copyWith(
        isSaving: false,
        error: result.failure.message,
      );
      return false;
    }
    return false;
  }
}

final scheduleEditProvider = StateNotifierProvider.family<ScheduleEditNotifier, ScheduleEditState, String>((ref, userId) {
  final repository = ref.watch(scheduleRepositoryProvider);
  return ScheduleEditNotifier(repository, userId);
});
