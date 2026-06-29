import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/emergency_alert.dart';
import '../../domain/failures/sos_failure.dart';
import '../../domain/repositories/i_sos_repository.dart';
import '../../../map/domain/entities/geo_point.dart';

/// Production [ISosRepository] using Supabase Postgres + Realtime.
///
/// Table: `sos_alerts`
/// Columns: id, sender_id, sender_name, latitude, longitude, status, created_at
class SupabaseSosRepository implements ISosRepository {
  SupabaseSosRepository({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  @override
  Stream<SosResult<List<EmergencyAlert>>> streamActiveAlerts() {
    final controller = StreamController<SosResult<List<EmergencyAlert>>>();

    Future<void> fetch() async {
      try {
        final data = await _client
            .from('sos_alerts')
            .select()
            .eq('status', EmergencyStatus.active.name)
            .order('created_at', ascending: false);

        final alerts = (data as List<dynamic>)
            .map((e) => _alertFromRow(e as Map<String, dynamic>))
            .toList();

        if (!controller.isClosed) {
          controller.add(SosSuccess<List<EmergencyAlert>>(alerts));
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(const SosFailed<List<EmergencyAlert>>(SosUnknownFailure()));
        }
      }
    }

    fetch();

    final subscription = _client
        .channel('sos_alerts:active')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'sos_alerts',
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      subscription.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<SosResult<void>> triggerAlert(EmergencyAlert alert) async {
    try {
      await _client.from('sos_alerts').insert(<String, dynamic>{
        'id': alert.id,
        'sender_id': alert.senderId,
        'sender_name': alert.senderName,
        'latitude': alert.location.latitude,
        'longitude': alert.location.longitude,
        'status': EmergencyStatus.active.name,
        'created_at': alert.timestamp.toUtc().toIso8601String(),
      });

      return const SosSuccess<void>(null);
    } on sb.PostgrestException catch (e) {
      return SosFailed<void>(AlertCreationFailed(e.message));
    } catch (e) {
      return SosFailed<void>(AlertCreationFailed(e.toString()));
    }
  }

  @override
  Future<SosResult<void>> resolveAlert(String alertId) async {
    try {
      await _client.from('sos_alerts').update(<String, dynamic>{
        'status': EmergencyStatus.resolved.name,
      }).eq('id', alertId);

      return const SosSuccess<void>(null);
    } on sb.PostgrestException catch (e) {
      return SosFailed<void>(AlertResolutionFailed(e.message));
    } catch (e) {
      return SosFailed<void>(AlertResolutionFailed(e.toString()));
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  EmergencyAlert _alertFromRow(Map<String, dynamic> row) {
    return EmergencyAlert(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String? ?? '',
      location: GeoPoint(
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
      ),
      status: EmergencyStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'active'),
        orElse: () => EmergencyStatus.active,
      ),
      timestamp: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}
