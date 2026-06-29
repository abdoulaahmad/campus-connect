import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../map/domain/entities/geo_point.dart';
import '../../../map/domain/failures/map_failure.dart';
import '../../domain/failures/sos_failure.dart';
import '../providers/sos_provider.dart';
import '../../../../core/providers/core_providers.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> with WidgetsBindingObserver {
  bool _isLocating = false;
  String? _locationError;
  bool _alertSent = false;
  GeoPoint? _resolvedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start the countdown on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sosNotifierProvider.notifier).startCountdown();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Stop loop sound & timer immediately if screen loses focus or app goes to background
      ref.read(sosNotifierProvider.notifier).cancelCountdown();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(sosNotifierProvider.notifier).cancelCountdown();
    super.dispose();
  }

  Future<void> _handleCountdownCompletion() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    final locationService = ref.read(locationServiceProvider);
    
    // 1. Try getCurrentLocation
    final result = await locationService.getCurrentLocation();
    GeoPoint? finalLocation;
    
    if (result is MapSuccess<GeoPoint>) {
      finalLocation = result.value;
    } else {
      // 2. Fallback to last known position
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          finalLocation = GeoPoint(latitude: position.latitude, longitude: position.longitude);
        }
      } catch (_) {
        // Fallback failed
      }
    }

    setState(() {
      _isLocating = false;
    });

    if (finalLocation == null) {
      setState(() {
        _locationError = 'Could not acquire GPS location. SOS alert blocked to prevent invalid signals.';
      });
      return;
    }

    _resolvedLocation = finalLocation;
    final userState = ref.read(authProvider);
    final user = userState is AuthAuthenticated ? userState.user : null;
    final senderId = user?.id ?? 'anonymous';
    final senderName = user?.name ?? 'FUD Student';

    final triggerResult = await ref.read(sosNotifierProvider.notifier).triggerEmergencyAlert(
      senderId: senderId,
      senderName: senderName,
      location: finalLocation,
    );

    if (triggerResult is SosSuccess<void>) {
      setState(() {
        _alertSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosNotifierProvider);

    // Listen for completion
    ref.listen<SosState>(sosNotifierProvider, (previous, next) {
      if (next.isTriggered && !(previous?.isTriggered ?? false)) {
        _handleCountdownCompletion();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0406), // Very dark crimson tint
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            ref.read(sosNotifierProvider.notifier).cancelCountdown();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!_alertSent && _locationError == null) ...[
                // SOS Active Blinking state
                Text(
                  sosState.isCountingDown ? 'EMERGENCY TRANSMISSION' : 'EMERGENCY SOS',
                  style: TextStyle(
                    color: Colors.redAccent.shade400,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Countdown circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing rings
                    if (sosState.isCountingDown)
                      _PulsingRing(seconds: sosState.remainingSeconds),
                    
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade800, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.15),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isLocating ? '...' : '${sosState.remainingSeconds}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 45),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    _isLocating 
                      ? 'Acquiring GPS location coordinates...'
                      : 'An emergency alert signal will be sent to campus security control in ${sosState.remainingSeconds} seconds.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // Slide To Cancel widget
                if (sosState.isCountingDown && !_isLocating)
                  SlideToAbortButton(
                    onAbort: () {
                      ref.read(sosNotifierProvider.notifier).cancelCountdown();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SOS Alert Aborted.'),
                          backgroundColor: Colors.blueGrey,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
              ] else if (_locationError != null) ...[
                // Location Error warning
                const Icon(
                  Icons.location_off_outlined,
                  color: Colors.amber,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'GPS Location Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _locationError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _locationError = null;
                    });
                    ref.read(sosNotifierProvider.notifier).reset();
                    ref.read(sosNotifierProvider.notifier).startCountdown();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ] else ...[
                // Success Transmission state
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 90,
                ),
                const SizedBox(height: 24),
                const Text(
                  'ALERT TRANSMITTED',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Campus Security Command and nearby responders have been notified of your emergency. Stay calm and remain where you are.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_resolvedLocation != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Signal Coordinates: ${_resolvedLocation!.latitude.toStringAsFixed(5)}, ${_resolvedLocation!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                const SizedBox(height: 48),
                OutlinedButton(
                  onPressed: () {
                    ref.read(sosNotifierProvider.notifier).reset();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Back to Home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  final int seconds;
  const _PulsingRing({required this.seconds});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 200 + (_controller.value * 60),
          height: 200 + (_controller.value * 60),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.withValues(alpha: 1.0 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class SlideToAbortButton extends StatefulWidget {
  final VoidCallback onAbort;
  const SlideToAbortButton({super.key, required this.onAbort});

  @override
  State<SlideToAbortButton> createState() => _SlideToAbortButtonState();
}

class _SlideToAbortButtonState extends State<SlideToAbortButton> {
  double _dragPosition = 0.0;
  static const double _sliderWidth = 280.0;
  static const double _handleSize = 50.0;

  @override
  Widget build(BuildContext context) {
    final maxDrag = _sliderWidth - _handleSize - 8.0;
    return Container(
      width: _sliderWidth,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Center(
            child: Opacity(
              opacity: (1.0 - (_dragPosition / maxDrag)).clamp(0.2, 1.0),
              child: const Text(
                'SLIDE TO CANCEL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Positioned(
            left: _dragPosition + 4.0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragPosition += details.delta.dx;
                  if (_dragPosition < 0) _dragPosition = 0;
                  if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragPosition >= maxDrag * 0.8) {
                  widget.onAbort();
                } else {
                  setState(() {
                    _dragPosition = 0.0;
                  });
                }
              },
              child: Container(
                width: _handleSize,
                height: _handleSize,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5252),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
