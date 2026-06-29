import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/messaging/domain/repositories/i_chat_repository.dart';
import '../../features/messaging/data/repositories/offline_chat_repository.dart';
import '../../features/messaging/data/datasources/local_message_datasource.dart';
import '../../features/messaging/data/services/sync_worker.dart';
import '../../features/marketplace/domain/repositories/i_marketplace_repository.dart';
import '../../features/map/domain/repositories/i_map_repository.dart';
import '../../features/map/domain/services/i_location_service.dart';
import '../../features/sos/domain/repositories/i_sos_repository.dart';
import '../../features/schedule/domain/repositories/i_schedule_repository.dart';
import '../../features/notifications/domain/repositories/i_notification_repository.dart';
import '../../features/admin/domain/repositories/i_admin_repository.dart';
import '../database/app_database.dart';
import '../services/connectivity_service.dart';
import '../services/qr_service.dart';

/// Base dependency injection provider slots for CampusConnect AUS.
///
/// Each provider defines a **contract slot** that throws [UnimplementedError]
/// by default. Concrete implementations are injected via [ProviderScope.overrides]
/// in `main.dart` based on the active [Environment].
///
/// **Pattern:**
/// 1. Domain layer defines abstract repository interface (`I*Repository`)
/// 2. This file declares the provider slot for that interface
/// 3. `main.dart` overrides the slot with the correct concrete class
/// 4. All presentation code consumes the provider — never the concrete class
///
/// **Sprint evolution:**
/// - Sprint 1: [appReadyProvider]
/// - Sprint 2: [authRepositoryProvider]
/// - Sprint 3: [chatRepositoryProvider]
/// - Sprint 4: [syncWorkerStateProvider] and offline database providers
 
// ── Sentinel Provider ─────────────────────────────────────────────────────

/// Indicates that [AppConfig.initialize()] has completed successfully.
///
/// Overridden to `true` in `main.dart` after [AppConfig.initialize] returns.
final appReadyProvider = Provider<bool>((ref) => false);

// ── Auth Repository Slot (Sprint 2) ──────────────────────────────────────

/// Dependency injection slot for [IAuthRepository].
///
/// Default throws [UnimplementedError] — must be overridden in `main.dart`.
///
/// **Overrides by environment:**
/// - `ENV=prod` → `FirebaseAuthRepository`
/// - `ENV=dev`  → `MockoonAuthRepository`
/// - `ENV=test` → `MockAuthRepository`
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  throw UnimplementedError(
    'authRepositoryProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});

// ── Chat Repository Slot (Sprint 3) ──────────────────────────────────────

/// Dependency injection slot for [IChatRepository].
///
/// Default throws [UnimplementedError] — must be overridden in `main.dart`.
final chatRepositoryProvider = Provider<IChatRepository>((ref) {
  throw UnimplementedError(
    'chatRepositoryProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});

// ── Offline Database & Sync Providers (Sprint 4) ─────────────────────────

/// Singleton SQLite database provider.
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

/// SQLite local message and chat data source.
final localMessageDatasourceProvider = Provider<LocalMessageDatasource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalMessageDatasource(db);
});

/// Device connection state checker.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return const ConnectivityService();
});

/// Stream of connectivity states.
final connectivityProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isOnline$;
});


/// Local sync queue worker.
final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final localDb = ref.watch(localMessageDatasourceProvider);
  final conn = ref.watch(connectivityServiceProvider);

  // Extract the underlying repository to prevent infinite retry loops
  final innerRepo = (chatRepo is OfflineChatRepository) ? chatRepo.inner : chatRepo;

  final worker = SyncWorker(
    inner: innerRepo,
    localDatasource: localDb,
    connectivity: conn,
  );

  ref.onDispose(() => worker.dispose());
  return worker;
});

/// Stream of sync queue events and status.
final syncWorkerStateProvider = StreamProvider<SyncWorkerState>((ref) {
  final worker = ref.watch(syncWorkerProvider);
  return worker.stateStream;
});

// ── Marketplace & QR Providers (Sprint 5) ─────────────────────────────────

/// Dependency injection slot for [IMarketplaceRepository].
final marketplaceRepositoryProvider = Provider<IMarketplaceRepository>((ref) {
  throw UnimplementedError(
    'marketplaceRepositoryProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});

/// QR Service provider singleton.
final qrServiceProvider = Provider<QrService>((ref) {
  return QrService();
});

// ── Campus Map & Geolocation Providers (Sprint 6) ─────────────────────────

/// Dependency injection slot for [IMapRepository].
final mapRepositoryProvider = Provider<IMapRepository>((ref) {
  throw UnimplementedError(
    'mapRepositoryProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});

/// Dependency injection slot for [ILocationService].
final locationServiceProvider = Provider<ILocationService>((ref) {
  throw UnimplementedError(
    'locationServiceProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});

// ── SOS Repository Slot (Sprint 7) ───────────────────────────────────────
final sosRepositoryProvider = Provider<ISosRepository>((ref) {
  throw UnimplementedError(
    'sosRepositoryProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});

// ── Schedule Repository Slot (Sprint 7) ──────────────────────────────────
final scheduleRepositoryProvider = Provider<IScheduleRepository>((ref) {
  throw UnimplementedError(
    'scheduleRepositoryProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});

// ── Notification Repository Slot (Sprint 7) ──────────────────────────────
final notificationRepositoryProvider = Provider<INotificationRepository>((ref) {
  throw UnimplementedError(
    'notificationRepositoryProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});

// ── Admin Repository Slot (Sprint 7) ─────────────────────────────────────
final adminRepositoryProvider = Provider<IAdminRepository>((ref) {
  throw UnimplementedError(
    'adminRepositoryProvider has not been overridden. '
    'Add the appropriate override to main.dart for the active environment.',
  );
});


