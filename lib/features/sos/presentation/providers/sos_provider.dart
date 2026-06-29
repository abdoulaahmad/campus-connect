import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../domain/repositories/i_sos_repository.dart';
import '../../domain/entities/emergency_alert.dart';
import '../../../map/domain/entities/geo_point.dart';
import '../../domain/failures/sos_failure.dart';
import '../../../../core/providers/core_providers.dart';

class SosState {
  final int remainingSeconds;
  final bool isCountingDown;
  final bool isTriggered;
  final String? error;
  
  const SosState({
    this.remainingSeconds = 10,
    this.isCountingDown = false,
    this.isTriggered = false,
    this.error,
  });

  SosState copyWith({
    int? remainingSeconds,
    bool? isCountingDown,
    bool? isTriggered,
    String? error,
  }) {
    return SosState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isCountingDown: isCountingDown ?? this.isCountingDown,
      isTriggered: isTriggered ?? this.isTriggered,
      error: error,
    );
  }
}

class SosNotifier extends StateNotifier<SosState> {
  final ISosRepository _sosRepository;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _timer;

  SosNotifier(this._sosRepository) : super(const SosState()) {
    try {
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (_) {
      // Handle platforms or environments where audio players are not supported
    }
  }

  void startCountdown() {
    if (state.isCountingDown || state.isTriggered) return;
    
    state = state.copyWith(
      remainingSeconds: 10,
      isCountingDown: true,
      isTriggered: false,
    );

    _playAlertSound();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 1) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _timer?.cancel();
        _stopAlertSound();
        state = state.copyWith(
          remainingSeconds: 0,
          isCountingDown: false,
          isTriggered: true,
        );
      }
    });
  }

  void cancelCountdown() {
    _timer?.cancel();
    _stopAlertSound();
    state = const SosState();
  }

  void reset() {
    _timer?.cancel();
    _stopAlertSound();
    state = const SosState();
  }

  Future<void> _playAlertSound() async {
    try {
      // Loop a warning sound. Ensure URL is direct and short
      await _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-84.wav'));
    } catch (_) {
      // Fail silently to prevent crash in unit tests or when offline
    }
  }

  void _stopAlertSound() {
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }

  Future<SosResult<void>> triggerEmergencyAlert({
    required String senderId,
    required String senderName,
    required GeoPoint location,
  }) async {
    final alert = EmergencyAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      senderName: senderName,
      location: location,
      status: EmergencyStatus.active,
      timestamp: DateTime.now(),
    );

    final result = await _sosRepository.triggerAlert(alert);
    if (result is SosFailed) {
      state = state.copyWith(error: result.failure.message);
    }
    return result;
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      _audioPlayer.stop();
      _audioPlayer.dispose();
    } catch (_) {}
    super.dispose();
  }
}

final sosNotifierProvider = StateNotifierProvider<SosNotifier, SosState>((ref) {
  final repository = ref.watch(sosRepositoryProvider);
  return SosNotifier(repository);
});

final activeAlertsProvider = StreamProvider<List<EmergencyAlert>>((ref) {
  final repository = ref.watch(sosRepositoryProvider);
  return repository.streamActiveAlerts().map((result) {
    if (result is SosSuccess<List<EmergencyAlert>>) {
      return result.value;
    } else {
      return [];
    }
  });
});
