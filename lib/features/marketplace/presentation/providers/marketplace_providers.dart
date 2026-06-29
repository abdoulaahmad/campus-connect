import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/listing.dart';
import '../../domain/failures/marketplace_failure.dart';

// ── Stream Providers ────────────────────────────────────────────────────────

/// Family stream provider exposing listings, optionally filtered by category.
/// Only streams active and unflagged listings, ordered by newest first.
final listingsStreamProvider = StreamProvider.family<List<Listing>, ListingCategory?>((Ref ref, ListingCategory? category) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.streamListings(category: category);
});

/// Family future provider for fetching details of a single listing.
final listingDetailsProvider = FutureProvider.family<MarketResult<Listing>, String>((Ref ref, String listingId) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.getListing(listingId);
});

// ── Mutation Actions Provider ──────────────────────────────────────────────

/// Helper class coordinating marketplace mutations and peer-to-peer verification flows.
class MarketplaceActions {
  const MarketplaceActions(this._ref);

  final Ref _ref;

  /// Creates a new listing for the currently authenticated user.
  Future<MarketResult<String>> createListing({
    required String title,
    required String description,
    required ListingCategory category,
    required double cost,
    String? imageUrl,
  }) async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthAuthenticated) {
      return const MarketFailed(PermissionDenied('You must be signed in to create listings.'));
    }

    if (cost < 0) {
      return const MarketFailed(InvalidCost());
    }

    final user = authState.user;
    final listing = Listing(
      id: const Uuid().v4(),
      sellerId: user.id,
      title: title,
      description: description,
      category: category,
      cost: cost,
      imageUrl: imageUrl,
      status: ListingStatus.active,
      isFlagged: false,
      createdAt: DateTime.now().toUtc(),
    );

    final repo = _ref.read(marketplaceRepositoryProvider);
    return repo.createListing(listing);
  }

  /// Deletes a listing. Enforces that only the seller can delete.
  Future<MarketResult<void>> deleteListing({
    required String listingId,
  }) async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthAuthenticated) {
      return const MarketFailed(PermissionDenied('You must be signed in to delete a listing.'));
    }

    final repo = _ref.read(marketplaceRepositoryProvider);
    return repo.deleteListing(listingId, authState.user.id);
  }

  /// Buyer scans the seller's QR code and completes transaction handshake.
  Future<MarketResult<void>> verifyHandshake({
    required String listingId,
    required String payload,
  }) async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthAuthenticated) {
      return const MarketFailed(PermissionDenied('You must be signed in to scan and buy items.'));
    }

    final repo = _ref.read(marketplaceRepositoryProvider);
    return repo.verifyHandshake(
      listingId: listingId,
      buyerId: authState.user.id,
      payload: payload,
    );
  }
}

/// Provider exposing [MarketplaceActions] for components.
final marketplaceActionsProvider = Provider<MarketplaceActions>((Ref ref) {
  return MarketplaceActions(ref);
});
