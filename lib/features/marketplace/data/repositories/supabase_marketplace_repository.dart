import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/listing.dart';
import '../../domain/failures/marketplace_failure.dart';
import '../../domain/repositories/i_marketplace_repository.dart';
import '../../../../core/services/qr_service.dart';

/// Production [IMarketplaceRepository] using Supabase Postgres + Realtime.
///
/// Table: `listings`
/// Columns: id, seller_id, title, description, category, cost, image_url,
///          status, is_flagged, buyer_id, verified_at, created_at
class SupabaseMarketplaceRepository implements IMarketplaceRepository {
  SupabaseMarketplaceRepository({
    required QrService qrService,
    sb.SupabaseClient? client,
  })  : _qrService = qrService,
        _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;
  final QrService _qrService;

  // ── streamListings ─────────────────────────────────────────────────────────

  @override
  Stream<List<Listing>> streamListings({ListingCategory? category}) {
    final controller = StreamController<List<Listing>>();

    Future<void> fetch() async {
      try {
        // Build filter chain before adding order (order returns a
        // PostgrestTransformBuilder which no longer accepts .eq).
        var filterQuery = _client
            .from('listings')
            .select()
            .eq('status', ListingStatus.active.name)
            .eq('is_flagged', false);

        if (category != null) {
          filterQuery = filterQuery.eq('category', category.name);
        }

        final data = await filterQuery.order('created_at', ascending: false);
        final listings = (data as List<dynamic>)
            .map((e) => _listingFromRow(e as Map<String, dynamic>))
            .toList();
        if (!controller.isClosed) controller.add(listings);
      } catch (_) {
        if (!controller.isClosed) controller.add(<Listing>[]);
      }
    }

    fetch();

    final subscription = _client
        .channel('listings:stream')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'listings',
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      subscription.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  // ── getListing ─────────────────────────────────────────────────────────────

  @override
  Future<MarketResult<Listing>> getListing(String listingId) async {
    try {
      final data = await _client
          .from('listings')
          .select()
          .eq('id', listingId)
          .maybeSingle();

      if (data == null) {
        return const MarketFailed<Listing>(ListingNotFound());
      }
      return MarketSuccess<Listing>(
          _listingFromRow(data as Map<String, dynamic>));
    } on sb.PostgrestException catch (e) {
      return MarketFailed<Listing>(MarketplaceUnknown(e.message));
    } catch (e) {
      return MarketFailed<Listing>(MarketplaceUnknown(e.toString()));
    }
  }

  // ── createListing ──────────────────────────────────────────────────────────

  @override
  Future<MarketResult<String>> createListing(Listing listing) async {
    if (listing.cost < 0) {
      return const MarketFailed<String>(InvalidCost());
    }
    try {
      final row = <String, dynamic>{
        'id': listing.id,
        'seller_id': listing.sellerId,
        'title': listing.title,
        'description': listing.description,
        'category': listing.category.name,
        'cost': listing.cost,
        'status': listing.status.name,
        'is_flagged': listing.isFlagged,
        'created_at': listing.createdAt.toUtc().toIso8601String(),
        if (listing.imageUrl != null) 'image_url': listing.imageUrl,
      };

      await _client.from('listings').insert(row);
      return MarketSuccess<String>(listing.id);
    } on sb.PostgrestException catch (e) {
      return MarketFailed<String>(MarketplaceUnknown(e.message));
    } catch (e) {
      return MarketFailed<String>(MarketplaceUnknown(e.toString()));
    }
  }

  // ── deleteListing ──────────────────────────────────────────────────────────

  @override
  Future<MarketResult<void>> deleteListing(
      String listingId, String currentUid) async {
    try {
      final data = await _client
          .from('listings')
          .select('seller_id')
          .eq('id', listingId)
          .maybeSingle();

      if (data == null) {
        return const MarketFailed<void>(ListingNotFound());
      }

      final sellerId =
          (data as Map<String, dynamic>)['seller_id'] as String?;
      if (sellerId != currentUid) {
        return const MarketFailed<void>(PermissionDenied());
      }

      await _client.from('listings').delete().eq('id', listingId);
      return const MarketSuccess<void>(null);
    } on sb.PostgrestException catch (e) {
      if (e.code == '42501') return const MarketFailed<void>(PermissionDenied());
      return MarketFailed<void>(MarketplaceUnknown(e.message));
    } catch (e) {
      return MarketFailed<void>(MarketplaceUnknown(e.toString()));
    }
  }

  // ── verifyHandshake ────────────────────────────────────────────────────────

  @override
  Future<MarketResult<void>> verifyHandshake({
    required String listingId,
    required String buyerId,
    required String payload,
  }) async {
    try {
      // Fetch seller_id to pass to verifyPayload (which validates it against payload).
      final listingData = await _client
          .from('listings')
          .select('seller_id, status')
          .eq('id', listingId)
          .maybeSingle();

      if (listingData == null) {
        return const MarketFailed<void>(ListingNotFound());
      }
      final rowMap = listingData as Map<String, dynamic>;
      if ((rowMap['status'] as String?) != ListingStatus.active.name) {
        return const MarketFailed<void>(ListingAlreadySold());
      }
      final sellerId = rowMap['seller_id'] as String;

      final bool valid = _qrService.verifyPayload(
        listingId: listingId,
        sellerId: sellerId,
        payload: payload,
      );
      if (!valid) {
        return const MarketFailed<void>(QrVerificationFailed());
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from('listings').update(<String, dynamic>{
        'status': ListingStatus.pending.name,
        'buyer_id': buyerId,
        'verified_at': now,
      }).eq('id', listingId).eq('status', ListingStatus.active.name);

      return const MarketSuccess<void>(null);
    } on sb.PostgrestException catch (e) {
      if (e.code == '42501') return const MarketFailed<void>(PermissionDenied());
      return MarketFailed<void>(MarketplaceUnknown(e.message));
    } catch (e) {
      return MarketFailed<void>(MarketplaceUnknown(e.toString()));
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  Listing _listingFromRow(Map<String, dynamic> row) {
    return Listing(
      id: row['id'] as String,
      sellerId: row['seller_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String,
      category: ListingCategory.values.firstWhere(
        (c) => c.name == (row['category'] as String? ?? 'other'),
        orElse: () => ListingCategory.other,
      ),
      cost: (row['cost'] as num).toDouble(),
      imageUrl: row['image_url'] as String?,
      status: ListingStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'active'),
        orElse: () => ListingStatus.active,
      ),
      isFlagged: row['is_flagged'] as bool? ?? false,
      buyerId: row['buyer_id'] as String?,
      verifiedAt: row['verified_at'] != null
          ? DateTime.tryParse(row['verified_at'] as String)
          : null,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}
