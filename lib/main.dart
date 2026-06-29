import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'features/messaging/data/repositories/offline_chat_repository.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/network/dio_client.dart';
import 'core/providers/core_providers.dart';
import 'core/services/secure_storage_service.dart';

// ── Auth repositories ──────────────────────────────────────────────────────
import 'features/auth/data/repositories/supabase_auth_repository.dart';
import 'features/auth/data/repositories/mock_auth_repository.dart';
import 'features/auth/data/repositories/mockoon_auth_repository.dart';

// ── Chat repositories ──────────────────────────────────────────────────────
import 'features/messaging/data/repositories/supabase_chat_repository.dart';
import 'features/messaging/data/repositories/mock_chat_repository.dart';
import 'features/messaging/data/repositories/mockoon_chat_repository.dart';

// ── Marketplace repositories ───────────────────────────────────────────────
import 'features/marketplace/data/repositories/supabase_marketplace_repository.dart';
import 'features/marketplace/data/repositories/mock_marketplace_repository.dart';
import 'features/marketplace/data/repositories/mockoon_marketplace_repository.dart';

// ── Map ────────────────────────────────────────────────────────────────────
import 'features/map/data/repositories/local_map_repository.dart';
import 'features/map/data/repositories/mock_map_repository.dart';
import 'features/map/data/services/location_service.dart';
import 'features/map/data/services/mock_location_service.dart';

// ── SOS repositories ───────────────────────────────────────────────────────
import 'features/sos/data/repositories/supabase_sos_repository.dart';
import 'features/sos/data/repositories/mock_sos_repository.dart';

// ── Other repositories ─────────────────────────────────────────────────────
import 'features/schedule/data/repositories/local_schedule_repository.dart';
import 'features/schedule/data/repositories/mock_schedule_repository.dart';
import 'features/notifications/data/repositories/mock_notification_repository.dart';
import 'features/notifications/data/repositories/supabase_notification_repository.dart';
import 'features/admin/data/repositories/local_admin_repository.dart';

/// CampusConnect AUS application entry point.
///
/// **Boot sequence:**
/// 1. Initialise Flutter engine bindings
/// 2. Load and validate `assets/config/config.json` via [AppConfig.initialize]
/// 3. Initialise Supabase (prod only — requires SUPABASE_URL + SUPABASE_ANON_KEY dart-defines)
/// 4. Wrap app in [ProviderScope] with ENV-appropriate provider overrides
/// 5. Launch [CampusConnectApp]
///
/// **Environment switching:**
/// ```bash
/// flutter run --dart-define=ENV=dev    # Mockoon (default)
/// flutter run --dart-define=ENV=prod \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJh...
/// flutter test --dart-define=ENV=test  # In-memory mocks
/// ```
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Validate CAM-AUS-11 + /api/v2/aus/ + ENV before anything else.
  debugPrint('[CampusConnect] Boot: Starting AppConfig initialization...');
  await AppConfig.initialize();
  debugPrint('[CampusConnect] Boot: AppConfig initialized. ENV=${AppConfig.environment}');

  // Step 2 (DEBUG): Run network diagnostics in dev mode.
  if (AppConfig.environment == Environment.dev) {
    debugPrint('[DIAG] ENV=dev detected. Resolved mockoonBaseUrl: ${AppConfig.mockoonBaseUrl}');
    debugPrint('[DIAG] If running on a physical phone, 10.0.2.2 will FAIL.');
    debugPrint('[DIAG] Fix: flutter run --dart-define=API_URL=http://<YOUR_LAN_IP>:3000/api/v2/aus/');
    await DioClient.logNetworkDiagnostics(AppConfig.mockoonBaseUrl);
  }

  // Step 3: Initialise Supabase for production only.
  if (AppConfig.environment == Environment.prod) {
    debugPrint('[CampusConnect] Boot: Initializing Supabase...');
    await _initSupabase();
    debugPrint('[CampusConnect] Boot: Supabase initialization complete');
  }

  // Step 4: Resolve provider overrides for active environment.
  debugPrint('[CampusConnect] Boot: Resolving provider overrides...');
  final List<Override> overrides = _resolveProviderOverrides();

  debugPrint('[CampusConnect] Boot: Starting app...');
  runApp(
    ProviderScope(
      overrides: overrides,
      child: const CampusConnectApp(),
    ),
  );
}

/// Initialises Supabase using dart-define values passed at build time.
///
/// Pass via:
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJh...
/// ```
Future<void> _initSupabase() async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint(
      '[CampusConnect] WARNING: SUPABASE_URL or SUPABASE_ANON_KEY not set. '
      'Pass via --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
    );
    return;
  }

  try {
    debugPrint('[CampusConnect] Initializing Supabase: $supabaseUrl');
    await sb.Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey, // ignore: deprecated_member_use
      authOptions: const sb.FlutterAuthClientOptions(
        authFlowType: sb.AuthFlowType.pkce,
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[CampusConnect] Supabase initialization timed out after 10s');
        throw TimeoutException('Supabase initialization timeout');
      },
    );
    debugPrint('[CampusConnect] Supabase initialized successfully');
  } on TimeoutException catch (e) {
    debugPrint('[CampusConnect] Supabase init timeout: $e');
  } on Object catch (e) {
    debugPrint('[CampusConnect] Supabase init failed: $e');
  }
}

/// Builds the [ProviderScope] overrides for the active [Environment].
List<Override> _resolveProviderOverrides() {
  final SecureStorageService storage = SecureStorageService();

  return <Override>[
    // Sentinel: config validated successfully.
    appReadyProvider.overrideWithValue(true),

    // ── Auth ────────────────────────────────────────────────────────────────
    authRepositoryProvider.overrideWithValue(
      switch (AppConfig.environment) {
        Environment.prod => SupabaseAuthRepository(storage: storage),
        Environment.dev => MockoonAuthRepository(
            dio: DioClient.create(baseUrl: AppConfig.mockoonBaseUrl),
            storage: storage,
          ),
        Environment.test => MockAuthRepository(storage: storage),
      },
    ),

    // ── Chat (wrapped with offline decorator) ────────────────────────────────
    chatRepositoryProvider.overrideWith((ref) {
      final innerRepo = switch (AppConfig.environment) {
        Environment.prod => SupabaseChatRepository(),
        Environment.dev => MockoonChatRepository(
            dio: DioClient.create(baseUrl: AppConfig.mockoonBaseUrl),
            storage: storage,
          ),
        Environment.test => MockChatRepository(storage: storage),
      };

      return OfflineChatRepository(
        inner: innerRepo,
        localDatasource: ref.watch(localMessageDatasourceProvider),
        connectivity: ref.watch(connectivityServiceProvider),
        getCurrentUserId: () async {
          if (AppConfig.environment == Environment.prod) {
            return sb.Supabase.instance.client.auth.currentUser?.id;
          }
          return storage.getLastUserId();
        },
      );
    }),

    // ── Marketplace ──────────────────────────────────────────────────────────
    marketplaceRepositoryProvider.overrideWith((ref) {
      final qrService = ref.watch(qrServiceProvider);
      return switch (AppConfig.environment) {
        Environment.prod => SupabaseMarketplaceRepository(qrService: qrService),
        Environment.dev => MockoonMarketplaceRepository(
            dio: DioClient.create(baseUrl: AppConfig.mockoonBaseUrl),
            qrService: qrService,
          ),
        Environment.test => MockMarketplaceRepository(qrService: qrService),
      };
    }),

    // ── Map ──────────────────────────────────────────────────────────────────
    mapRepositoryProvider.overrideWith((ref) {
      return switch (AppConfig.environment) {
        Environment.prod || Environment.dev =>
          LocalMapRepository(ref.watch(appDatabaseProvider)),
        Environment.test => MockMapRepository(),
      };
    }),

    // ── Location service ─────────────────────────────────────────────────────
    locationServiceProvider.overrideWith((ref) {
      return switch (AppConfig.environment) {
        Environment.prod || Environment.dev => const LocationService(),
        Environment.test => MockLocationService(),
      };
    }),

    // ── SOS ──────────────────────────────────────────────────────────────────
    sosRepositoryProvider.overrideWith((ref) {
      return switch (AppConfig.environment) {
        Environment.prod => SupabaseSosRepository(),
        Environment.dev || Environment.test => MockSosRepository(),
      };
    }),

    // ── Schedule ─────────────────────────────────────────────────────────────
    scheduleRepositoryProvider.overrideWith((ref) {
      return switch (AppConfig.environment) {
        Environment.prod || Environment.dev =>
          LocalScheduleRepository(dbHelper: ref.watch(appDatabaseProvider)),
        Environment.test => MockScheduleRepository(),
      };
    }),

    // ── Notifications ────────────────────────────────────────────────────────
    notificationRepositoryProvider.overrideWith((_) {
      return switch (AppConfig.environment) {
        Environment.prod => SupabaseNotificationRepository(),
        Environment.dev || Environment.test => MockNotificationRepository(),
      };
    }),

    // ── Admin ────────────────────────────────────────────────────────────────
    adminRepositoryProvider.overrideWith(
      (ref) => LocalAdminRepository(dbHelper: ref.watch(appDatabaseProvider)),
    ),
  ];
}
