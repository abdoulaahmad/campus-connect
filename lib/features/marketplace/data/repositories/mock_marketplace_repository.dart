import 'dart:async';
import '../../../../core/services/qr_service.dart';
import '../../domain/entities/listing.dart';
import '../../domain/failures/marketplace_failure.dart';
import '../../domain/repositories/i_marketplace_repository.dart';

/// Test environment in-memory mock implementation of [IMarketplaceRepository].
class MockMarketplaceRepository implements IMarketplaceRepository {
  final QrService _qrService;
  
  // In-memory database
  final List<Listing> _listings = <Listing>[];
  
  // Stream controller to broadcast listings updates
  final StreamController<List<Listing>> _listingsController = StreamController<List<Listing>>.broadcast();

  // Allow setting a custom time provider for testing QR expiration
  DateTime Function()? _timeProvider;

  MockMarketplaceRepository({
    required QrService qrService,
    DateTime Function()? timeProvider,
  })  : _qrService = qrService,
        _timeProvider = timeProvider {
    _initSeedData();
  }

  /// Sets or clears a custom time provider.
  void setTimeProvider(DateTime Function()? provider) {
    _timeProvider = provider;
  }

  void _initSeedData() {
    final now = DateTime.now().toUtc();
    _listings.addAll([
      Listing(
        id: 'L001',
        sellerId: 'uid_seller_1',
        title: 'Engineering Mathematics Textbook',
        description: 'Advanced Engineering Mathematics, 10th Edition. Barely used, no highlights.',
        category: ListingCategory.books,
        cost: 4500.00,
        imageUrl: 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=200',
        status: ListingStatus.active,
        isFlagged: false,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      Listing(
        id: 'L002',
        sellerId: 'uid_seller_2',
        title: 'Dell Laptop Charger 65W',
        description: 'Original Dell USB-C charger, 65W power delivery. Working perfectly.',
        category: ListingCategory.electronics,
        cost: 12000.00,
        imageUrl: 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=200',
        status: ListingStatus.active,
        isFlagged: false,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      Listing(
        id: 'L003',
        sellerId: 'uid_seller_1',
        title: 'Ahmadu University Custom Hoodie',
        description: 'Size L, maroon color with university crest. Warm and comfortable.',
        category: ListingCategory.clothing,
        cost: 7500.00,
        imageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=200',
        status: ListingStatus.active,
        isFlagged: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Listing(
        id: 'L004',
        sellerId: 'uid_seller_3',
        title: 'Maths Tutoring — Calculus & Algebra',
        description: 'Private 1-on-1 sessions for 100/200 level students. 1.5 hours per session.',
        category: ListingCategory.services,
        cost: 3000.00,
        imageUrl: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=200',
        status: ListingStatus.active,
        isFlagged: false,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      Listing(
        id: 'L005',
        sellerId: 'uid_seller_4',
        title: 'Drafting Board with T-Square',
        description: 'Standard engineering drawing board, size A1. Comes with transparent bag.',
        category: ListingCategory.other,
        cost: 15000.00,
        imageUrl: 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=200',
        status: ListingStatus.active,
        isFlagged: false,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ]);
  }

  void _notifyListeners() {
    if (!_listingsController.isClosed) {
      _listingsController.add(List<Listing>.from(_listings));
    }
  }

  @override
  Stream<List<Listing>> streamListings({ListingCategory? category}) {
    // Return a stream that filters out sold, pending, cancelled, or flagged listings,
    // sorted by createdAt DESC (newest first).
    final controller = StreamController<List<Listing>>.broadcast();
    
    void pushFiltered() {
      final filtered = _listings.where((listing) {
        if (listing.status != ListingStatus.active) return false;
        if (listing.isFlagged) return false;
        if (category != null && listing.category != category) return false;
        return true;
      }).toList();
      
      // Sort: newest first
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      if (!controller.isClosed) {
        controller.add(filtered);
      }
    }

    // Push initial values after subscription
    Timer(const Duration(milliseconds: 50), pushFiltered);

    // Listen to parent list updates
    final subscription = _listingsController.stream.listen((_) => pushFiltered());
    
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<MarketResult<Listing>> getListing(String listingId) async {
    final index = _listings.indexWhere((l) => l.id == listingId);
    if (index == -1) {
      return const MarketFailed(ListingNotFound());
    }
    return MarketSuccess(_listings[index]);
  }

  @override
  Future<MarketResult<String>> createListing(Listing listing) async {
    if (listing.cost < 0) {
      return const MarketFailed(InvalidCost());
    }

    // Seed/Save listing
    final now = _timeProvider != null ? _timeProvider!() : DateTime.now().toUtc();
    final newListing = Listing(
      id: listing.id.isNotEmpty ? listing.id : 'L_${now.millisecondsSinceEpoch}',
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

    _listings.add(newListing);
    _notifyListeners();
    return MarketSuccess(newListing.id);
  }

  @override
  Future<MarketResult<void>> deleteListing(String listingId, String currentUid) async {
    final index = _listings.indexWhere((l) => l.id == listingId);
    if (index == -1) {
      return const MarketFailed(ListingNotFound());
    }

    final listing = _listings[index];
    if (listing.sellerId != currentUid) {
      return const MarketFailed(PermissionDenied());
    }

    _listings.removeAt(index);
    _notifyListeners();
    return const MarketSuccess(null);
  }

  @override
  Future<MarketResult<void>> verifyHandshake({
    required String listingId,
    required String buyerId,
    required String payload,
  }) async {
    final index = _listings.indexWhere((l) => l.id == listingId);
    if (index == -1) {
      return const MarketFailed(ListingNotFound());
    }

    final listing = _listings[index];
    if (listing.status != ListingStatus.active) {
      return const MarketFailed(ListingAlreadySold());
    }

    // Verify QR payload
    final now = _timeProvider != null ? _timeProvider!() : DateTime.now().toUtc();
    final reason = _qrService.validatePayloadReason(
      payload: payload,
      listingId: listingId,
      sellerId: listing.sellerId,
      mockTime: now,
    );

    if (reason != null) {
      if (reason == 'expired') {
        return const MarketFailed(QrExpired());
      }
      return const MarketFailed(QrVerificationFailed());
    }

    // Update status to pending and record buyer details
    _listings[index] = listing.copyWith(
      status: ListingStatus.pending,
      buyerId: buyerId,
      verifiedAt: now,
    );

    _notifyListeners();
    return const MarketSuccess(null);
  }
}
