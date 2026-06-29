import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/services/qr_service.dart';
import '../../domain/entities/listing.dart';
import '../../domain/failures/marketplace_failure.dart';
import '../../domain/repositories/i_marketplace_repository.dart';
import '../models/listing_model.dart';

/// Development environment Mockoon API repository implementation of [IMarketplaceRepository].
class MockoonMarketplaceRepository implements IMarketplaceRepository {
  final Dio _dio;
  final QrService _qrService;

  MockoonMarketplaceRepository({
    required Dio dio,
    required QrService qrService,
  })  : _dio = dio,
        _qrService = qrService;

  MarketplaceFailure _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout) {
      return const MarketplaceUnknown('Network connection timeout. Please try again.');
    }
    if (e.response?.statusCode == 404) {
      return const ListingNotFound();
    }
    if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
      return const PermissionDenied();
    }
    return MarketplaceUnknown(e.message ?? 'Server connection error.');
  }

  @override
  Stream<List<Listing>> streamListings({ListingCategory? category}) {
    final controller = StreamController<List<Listing>>.broadcast();
    Timer? timer;

    Future<void> fetch() async {
      try {
        final queryParams = <String, dynamic>{};
        if (category != null) {
          queryParams['category'] = category.name;
        }

        final response = await _dio.get<List<dynamic>>('/listings', queryParameters: queryParams);

        if (response.data != null) {
          final listings = response.data!.map((dynamic item) {
            final map = item as Map<String, dynamic>;
            return ListingModel.fromMap(map['id']?.toString() ?? '', map);
          }).where((listing) {
            // Only stream listings that are active and not flagged
            return listing.status == ListingStatus.active && !listing.isFlagged;
          }).toList();

          // Sort by newest first
          listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (!controller.isClosed) {
            controller.add(listings);
          }
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(<Listing>[]);
        }
      }
    }

    // Initial fetch
    fetch();

    // Poll every 3 seconds to update UI in dev
    timer = Timer.periodic(const Duration(seconds: 3), (_) => fetch());

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<MarketResult<Listing>> getListing(String listingId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/listings/$listingId');
      if (response.data != null) {
        final listing = ListingModel.fromMap(listingId, response.data!);
        return MarketSuccess(listing);
      }
      return const MarketFailed(ListingNotFound());
    } on DioException catch (e) {
      return MarketFailed(_handleDioError(e));
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
      final model = ListingModel(
        id: listing.id,
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

      final response = await _dio.post<Map<String, dynamic>>(
        '/listings',
        data: model.toJson(),
      );

      final newId = response.data?['id']?.toString() ?? listing.id;
      return MarketSuccess(newId);
    } on DioException catch (e) {
      return MarketFailed(_handleDioError(e));
    } catch (e) {
      return MarketFailed(MarketplaceUnknown(e.toString()));
    }
  }

  @override
  Future<MarketResult<void>> deleteListing(String listingId, String currentUid) async {
    try {
      // First verify ownership
      final getRes = await getListing(listingId);
      if (getRes is MarketFailed) {
        return MarketFailed((getRes as MarketFailed).failure);
      }

      final listing = (getRes as MarketSuccess<Listing>).value;
      if (listing.sellerId != currentUid) {
        return const MarketFailed(PermissionDenied());
      }

      await _dio.delete<dynamic>('/listings/$listingId');
      return const MarketSuccess(null);
    } on DioException catch (e) {
      return MarketFailed(_handleDioError(e));
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
      // 1. Get current listing state
      final getRes = await getListing(listingId);
      if (getRes is MarketFailed) {
        return MarketFailed((getRes as MarketFailed).failure);
      }

      final listing = (getRes as MarketSuccess<Listing>).value;

      // 2. Enforce active status
      if (listing.status != ListingStatus.active) {
        return const MarketFailed(ListingAlreadySold());
      }

      // 3. Verify payload expiration & content
      final reason = _qrService.validatePayloadReason(
        payload: payload,
        listingId: listingId,
        sellerId: listing.sellerId,
      );

      if (reason != null) {
        if (reason == 'expired') {
          return const MarketFailed(QrExpired());
        }
        return const MarketFailed(QrVerificationFailed());
      }

      // 4. Update status to pending
      final now = DateTime.now().toUtc();
      await _dio.patch<dynamic>(
        '/listings/$listingId/verify',
        data: <String, dynamic>{
          'status': ListingStatus.pending.name,
          'buyer_id': buyerId,
          'verified_at': now.toIso8601String(),
        },
      );

      return const MarketSuccess(null);
    } on DioException catch (e) {
      return MarketFailed(_handleDioError(e));
    } catch (e) {
      return MarketFailed(MarketplaceUnknown(e.toString()));
    }
  }
}
