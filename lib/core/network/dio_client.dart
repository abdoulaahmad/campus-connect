import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Dio HTTP client factory for DEV environment Mockoon requests.
///
/// Only instantiated when `ENV=dev`. Never used in `prod` or `test`.
/// Firebase SDK handles all HTTP communication in production.
///
/// **Mockoon server:** `http://10.0.2.2:3000/api/v2/aus/`
/// - `10.0.2.2` resolves to `localhost` from Android/iOS emulators
/// - Port 3000 is the default Mockoon port
///
/// **Interceptors:**
/// - Logging interceptor (debug only) — logs request/response pairs
/// - Timeout: 15 seconds connect, 15 seconds receive
abstract final class DioClient {
  DioClient._();

  /// Prints network interface addresses to help diagnose physical-device
  /// connectivity issues. Call once at app startup in dev mode.
  static Future<void> logNetworkDiagnostics(String resolvedBaseUrl) async {
    debugPrint('[DIAG] ──────────────────────────────────────────');
    debugPrint('[DIAG] DioClient.logNetworkDiagnostics()');
    debugPrint('[DIAG] Resolved Mockoon baseUrl: $resolvedBaseUrl');
    debugPrint('[DIAG] NOTE: 10.0.2.2 only works in Android emulator.');
    debugPrint('[DIAG]       Physical phones need your machine\'s LAN IP.');
    debugPrint('[DIAG]       Pass --dart-define=API_URL=http://<YOUR_IP>:3000/api/v2/aus/');

    try {
      final interfaces = await NetworkInterface.list();
      if (interfaces.isEmpty) {
        debugPrint('[DIAG] No network interfaces found — device may be offline.');
      } else {
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            debugPrint('[DIAG] Interface: ${iface.name}  addr: ${addr.address}');
          }
        }
      }
    } on Object catch (e) {
      debugPrint('[DIAG] Could not list network interfaces: $e');
    }

    // Attempt a TCP connection to the Mockoon host+port to give a clear
    // pass/fail signal rather than waiting for a Dio timeout.
    try {
      final uri = Uri.parse(resolvedBaseUrl);
      final host = uri.host;
      final port = uri.port == 0 ? 3000 : uri.port;
      debugPrint('[DIAG] Probing TCP $host:$port …');
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      debugPrint('[DIAG] ✅ TCP probe SUCCESS — Mockoon is reachable.');
    } on SocketException catch (e) {
      debugPrint('[DIAG] ❌ TCP probe FAILED: ${e.message}');
      debugPrint('[DIAG]    → Most likely cause: wrong host address for physical device.');
      debugPrint('[DIAG]    → Fix: flutter run --dart-define=API_URL=http://<YOUR_LAN_IP>:3000/api/v2/aus/');
    } on Object catch (e) {
      debugPrint('[DIAG] ❌ TCP probe error: $e');
    }

    debugPrint('[DIAG] ──────────────────────────────────────────');
  }

  /// Creates and configures a [Dio] instance for Mockoon requests.
  ///
  /// Returns a new instance on each call — callers are responsible
  /// for caching if needed (typically done via Riverpod provider).
  static Dio create({String? baseUrl}) {
    final String resolvedBase = baseUrl ?? 'http://10.0.2.2:3000/api/v2/aus/';

    final Dio dio = Dio(
      BaseOptions(
        baseUrl: resolvedBase,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Campus-Code': 'CAM-AUS-11',
        },
      ),
    );

    // Add logging interceptor for dev debugging.
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        error: true,
      ),
    );

    // Add a diagnostic interceptor that surfaces connection errors clearly.
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) {
          if (err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.receiveTimeout ||
              err.type == DioExceptionType.connectionError) {
            debugPrint('[NETWORK] ❌ Connection error to ${err.requestOptions.baseUrl}');
            debugPrint('[NETWORK]    type     : ${err.type}');
            debugPrint('[NETWORK]    message  : ${err.message}');
            debugPrint('[NETWORK]    → Physical device cannot reach 10.0.2.2.');
            debugPrint('[NETWORK]    → Run with: flutter run --dart-define=API_URL=http://<YOUR_LAN_IP>:3000/api/v2/aus/');
          }
          handler.next(err);
        },
      ),
    );

    return dio;
  }
}
