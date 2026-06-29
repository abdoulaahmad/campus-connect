import '../entities/listing.dart';
import '../failures/marketplace_failure.dart';

/// Abstract repository interface defining marketplace business logic operations.
abstract class IMarketplaceRepository {
  /// Emits a stream of listing items, optionally filtered by category.
  /// Only returns listings with [ListingStatus.active] and that are not flagged.
  Stream<List<Listing>> streamListings({ListingCategory? category});

  /// Retrieves a single listing by its ID.
  Future<MarketResult<Listing>> getListing(String listingId);

  /// Creates a new listing in the repository.
  /// Validates that listing.cost >= 0.00.
  Future<MarketResult<String>> createListing(Listing listing);

  /// Deletes a listing. Enforces that only the seller (matching [currentUid])
  /// can delete their listing.
  Future<MarketResult<void>> deleteListing(String listingId, String currentUid);

  /// Verifies the handshake for a purchase transaction.
  /// Validates the [payload] from the scanned QR code.
  /// If verified, transitions status to [ListingStatus.pending], setting [buyerId]
  /// and [verifiedAt].
  Future<MarketResult<void>> verifyHandshake({
    required String listingId,
    required String buyerId,
    required String payload,
  });
}
