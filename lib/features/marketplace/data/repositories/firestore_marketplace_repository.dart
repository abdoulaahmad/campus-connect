import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/qr_service.dart';
import '../../domain/entities/listing.dart';
import '../../domain/failures/marketplace_failure.dart';
import '../../domain/repositories/i_marketplace_repository.dart';
import '../models/listing_model.dart';

/// Production Firestore repository implementation of [IMarketplaceRepository].
class FirestoreMarketplaceRepository implements IMarketplaceRepository {
  final FirebaseFirestore _firestore;
  final QrService _qrService;

  FirestoreMarketplaceRepository({
    required FirebaseFirestore firestore,
    required QrService qrService,
  })  : _firestore = firestore,
        _qrService = qrService;

  @override
  Stream<List<Listing>> streamListings({ListingCategory? category}) {
    Query query = _firestore.collection('listings')
        .where('status', isEqualTo: ListingStatus.active.name)
        .where('is_flagged', isEqualTo: false);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    // Sort newest first
    query = query.orderBy('created_at', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ListingModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  @override
  Future<MarketResult<Listing>> getListing(String listingId) async {
    try {
      final doc = await _firestore.collection('listings').doc(listingId).get();
      if (!doc.exists) {
        return const MarketFailed(ListingNotFound());
      }
      final data = doc.data() as Map<String, dynamic>;
      final listing = ListingModel.fromMap(doc.id, data);
      return MarketSuccess(listing);
    } catch (e) {
      return MarketFailed(MarketplaceUnknown(e.toString()));
    }
  }

  @override
  Future<MarketResult<String>> createListing(Listing listing) async {
    if (listing.cost < 0) {
      return const MarketFailed(InvalidCost());
    }

    try {
      final docRef = _firestore.collection('listings').doc(
        listing.id.isNotEmpty ? listing.id : null,
      );

      final model = ListingModel(
        id: docRef.id,
        sellerId: listing.sellerId,
        title: listing.title,
        description: listing.description,
        category: listing.category,
        cost: listing.cost,
        imageUrl: listing.imageUrl,
        status: listing.status,
        isFlagged: listing.isFlagged,
        buyerId: listing.buyerId,
        verifiedAt: listing.verifiedAt,
        createdAt: listing.createdAt,
      );

      await docRef.set(model.toFirestore());
      return MarketSuccess(docRef.id);
    } catch (e) {
      return MarketFailed(MarketplaceUnknown(e.toString()));
    }
  }

  @override
  Future<MarketResult<void>> deleteListing(String listingId, String currentUid) async {
    try {
      final docRef = _firestore.collection('listings').doc(listingId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        return const MarketFailed(ListingNotFound());
      }

      final data = doc.data() as Map<String, dynamic>;
      final sellerId = data['seller_id'] as String?;

      if (sellerId != currentUid) {
        return const MarketFailed(PermissionDenied());
      }

      await docRef.delete();
      return const MarketSuccess(null);
    } catch (e) {
      return MarketFailed(MarketplaceUnknown(e.toString()));
    }
  }

  @override
  Future<MarketResult<void>> verifyHandshake({
    required String listingId,
    required String buyerId,
    required String payload,
  }) async {
    try {
      final docRef = _firestore.collection('listings').doc(listingId);

      final result = await _firestore.runTransaction<MarketResult<void>>((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          return const MarketFailed(ListingNotFound());
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final statusStr = data['status'] as String?;

        if (statusStr != ListingStatus.active.name) {
          return const MarketFailed(ListingAlreadySold());
        }

        final sellerId = data['seller_id'] as String? ?? '';
        final isFlagged = data['is_flagged'] as bool? ?? false;

        if (isFlagged) {
          return const MarketFailed(ListingNotFound());
        }

        // Validate payload using QrService
        final reason = _qrService.validatePayloadReason(
          payload: payload,
          listingId: listingId,
          sellerId: sellerId,
        );

        if (reason != null) {
          if (reason == 'expired') {
            return const MarketFailed(QrExpired());
          }
          return const MarketFailed(QrVerificationFailed());
        }

        final now = DateTime.now().toUtc();
        transaction.update(docRef, {
          'status': ListingStatus.pending.name,
          'buyer_id': buyerId,
          'verified_at': Timestamp.fromDate(now),
        });

        return const MarketSuccess(null);
      });

      return result;
    } catch (e) {
      return MarketFailed(MarketplaceUnknown(e.toString()));
    }
  }
}
