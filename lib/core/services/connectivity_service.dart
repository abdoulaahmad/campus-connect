import 'dart:async';
import 'dart:io';

class ConnectivityService {
  const ConnectivityService();

  static bool? _mockOnline;
  static final _mockController = StreamController<bool>.broadcast();

  /// Globally sets a mock online status and notifies active streams immediately.
  static void setMockOnline(bool? isOnline) {
    _mockOnline = isOnline;
    if (isOnline != null) {
      _mockController.add(isOnline);
    }
  }

  /// Stream emitting connectivity status.
  Stream<bool> get isOnline$ {
    final controller = StreamController<bool>.broadcast();
    Timer? timer;
    StreamSubscription? mockSub;

    void check() async {
      final online = await isOnlineNow;
      if (!controller.isClosed) {
        controller.add(online);
      }
    }

    check();

    // Poll periodically to catch real network changes
    timer = Timer.periodic(const Duration(seconds: 3), (_) => check());

    // Listen to mock overrides to emit changes instantly
    mockSub = _mockController.stream.listen((val) {
      if (!controller.isClosed) {
        controller.add(val);
      }
    });

    controller.onCancel = () {
      timer?.cancel();
      mockSub?.cancel();
    };

    return controller.stream;
  }

  /// Resolves to true if the device is currently online.
  Future<bool> get isOnlineNow async {
    if (_mockOnline != null) {
      return _mockOnline!;
    }
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(milliseconds: 1500));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
