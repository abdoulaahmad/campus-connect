import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/core/services/qr_service.dart';
import 'package:campus_connect/features/marketplace/domain/entities/listing.dart';
import 'package:campus_connect/features/marketplace/domain/failures/marketplace_failure.dart';
import 'package:campus_connect/features/marketplace/data/repositories/mock_marketplace_repository.dart';

void main() {
  late QrService qrService;
  late MockMarketplaceRepository repo;

  setUp(() {
    qrService = QrService();
    repo = MockMarketplaceRepository(qrService: qrService);
  });

  group('Marketplace Repository Tests', () {
    test('1. streamListings() no filter returns all active/unflagged listings', () async {
      final listings = await repo.streamListings().first;
      expect(listings.length, 5);
      expect(listings.every((l) => l.status == ListingStatus.active && !l.isFlagged), isTrue);
    });

    test('2. streamListings(category: books) returns filtered listings', () async {
      final listings = await repo.streamListings(category: ListingCategory.books).first;
      expect(listings.length, 1);
      expect(listings.first.category, ListingCategory.books);
    });

    test('3. createListing with negative cost returns InvalidCost failure', () async {
      final listing = Listing(
        id: 'L999',
        sellerId: 'uid_seller_1',
        title: 'Negative cost book',
        description: 'Testing',
        category: ListingCategory.books,
        cost: -100.0,
        createdAt: DateTime.now().toUtc(),
      );
      final result = await repo.createListing(listing);
      expect(result, isA<MarketFailed>());
      final failure = (result as MarketFailed).failure;
      expect(failure, isA<InvalidCost>());
    });

    test('4. verifyHandshake valid payload within 15 min updates status to pending', () async {
      final listingId = 'L001';
      final sellerId = 'uid_seller_1';
      final buyerId = 'uid_buyer_1';
      
      final payload = qrService.generatePayload(listingId: listingId, sellerId: sellerId);
      final result = await repo.verifyHandshake(
        listingId: listingId,
        buyerId: buyerId,
        payload: payload,
      );

      expect(result, isA<MarketSuccess>());
      
      final getRes = await repo.getListing(listingId);
      expect(getRes, isA<MarketSuccess>());
      final listing = (getRes as MarketSuccess<Listing>).value;
      expect(listing.status, ListingStatus.pending);
      expect(listing.buyerId, buyerId);
      expect(listing.verifiedAt, isNotNull);
    });

    test('5. verifyHandshake expired payload returns QrExpired failure', () async {
      final listingId = 'L001';
      final sellerId = 'uid_seller_1';
      final buyerId = 'uid_buyer_1';

      // Set custom time provider on mock repo to simulate time progression
      final generationTime = DateTime.now().toUtc();
      final payload = qrService.generatePayload(
        listingId: listingId,
        sellerId: sellerId,
        mockTime: generationTime,
      );

      // Fast forward repository clock by 16 minutes
      final verifyTime = generationTime.add(const Duration(minutes: 16));
      repo.setTimeProvider(() => verifyTime);

      final result = await repo.verifyHandshake(
        listingId: listingId,
        buyerId: buyerId,
        payload: payload,
      );

      expect(result, isA<MarketFailed>());
      final failure = (result as MarketFailed).failure;
      expect(failure, isA<QrExpired>());
    });

    test('6. verifyHandshake tampered payload returns QrVerificationFailed failure', () async {
      final listingId = 'L001';
      final sellerId = 'uid_seller_1';
      final buyerId = 'uid_buyer_1';

      // Tampered payload has wrong listingId
      final payload = qrService.generatePayload(listingId: 'L002', sellerId: sellerId);

      final result = await repo.verifyHandshake(
        listingId: listingId,
        buyerId: buyerId,
        payload: payload,
      );

      expect(result, isA<MarketFailed>());
      final failure = (result as MarketFailed).failure;
      expect(failure, isA<QrVerificationFailed>());
    });

    test('7. verifyHandshake on already-sold listing returns ListingAlreadySold failure', () async {
      final listingId = 'L001';
      final sellerId = 'uid_seller_1';
      final buyerId = 'uid_buyer_1';

      // Complete a valid handshake first
      final payload = qrService.generatePayload(listingId: listingId, sellerId: sellerId);
      await repo.verifyHandshake(listingId: listingId, buyerId: buyerId, payload: payload);

      // Attempt second handshake on same listing
      final result2 = await repo.verifyHandshake(
        listingId: listingId,
        buyerId: 'uid_buyer_2',
        payload: payload,
      );

      expect(result2, isA<MarketFailed>());
      final failure = (result2 as MarketFailed).failure;
      expect(failure, isA<ListingAlreadySold>());
    });

    test('8. deleteListing by non-owner returns PermissionDenied failure', () async {
      final listingId = 'L001'; // Owner is uid_seller_1
      final result = await repo.deleteListing(listingId, 'uid_not_owner');
      
      expect(result, isA<MarketFailed>());
      final failure = (result as MarketFailed).failure;
      expect(failure, isA<PermissionDenied>());
    });

    test('9. getListing unknown ID returns ListingNotFound failure', () async {
      final result = await repo.getListing('L999_unknown');
      expect(result, isA<MarketFailed>());
      final failure = (result as MarketFailed).failure;
      expect(failure, isA<ListingNotFound>());
    });
  });
}
