import 'package:meta/meta.dart';

/// Categories available for listings in the marketplace.
enum ListingCategory { books, electronics, clothing, services, other }

/// Status indicating the lifecycle of a listing in the marketplace.
enum ListingStatus {
  /// Listing is active and available for purchase.
  active,

  /// QR code scanned, transaction pending seller/buyer confirmation.
  pending,

  /// Transaction completed successfully.
  sold,

  /// Listing was cancelled by the seller.
  cancelled,
}

/// Core domain entity representing a marketplace listing.
@immutable
class Listing {
  /// Unique identifier of the listing.
  final String id;

  /// UID of the user selling the item.
  final String sellerId;

  /// Title of the listing.
  final String title;

  /// Detailed description of the listing.
  final String description;

  /// Category classification of the item.
  final ListingCategory category;

  /// Cost of the item. Must be >= 0.0.
  final double cost;

  /// Optional image URL for the item.
  final String? imageUrl;

  /// Lifecycle status of the listing.
  final ListingStatus status;

  /// Admin moderation flag.
  final bool isFlagged;

  /// UID of the buyer who purchased the item (set upon successful handshake).
  final String? buyerId;

  /// Time when transaction was verified (set upon successful handshake).
  final DateTime? verifiedAt;

  /// Time when the listing was created.
  final DateTime createdAt;

  const Listing({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.category,
    required this.cost,
    this.imageUrl,
    this.status = ListingStatus.active,
    this.isFlagged = false,
    this.buyerId,
    this.verifiedAt,
    required this.createdAt,
  });

  /// Creates a copy of this listing with some fields replaced.
  Listing copyWith({
    String? id,
    String? sellerId,
    String? title,
    String? description,
    ListingCategory? category,
    double? cost,
    String? imageUrl,
    ListingStatus? status,
    bool? isFlagged,
    String? buyerId,
    DateTime? verifiedAt,
    DateTime? createdAt,
  }) {
    return Listing(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      cost: cost ?? this.cost,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      isFlagged: isFlagged ?? this.isFlagged,
      buyerId: buyerId ?? this.buyerId,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Listing &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sellerId == other.sellerId &&
          title == other.title &&
          description == other.description &&
          category == other.category &&
          cost == other.cost &&
          imageUrl == other.imageUrl &&
          status == other.status &&
          isFlagged == other.isFlagged &&
          buyerId == other.buyerId &&
          verifiedAt == other.verifiedAt &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      sellerId.hashCode ^
      title.hashCode ^
      description.hashCode ^
      category.hashCode ^
      cost.hashCode ^
      imageUrl.hashCode ^
      status.hashCode ^
      isFlagged.hashCode ^
      buyerId.hashCode ^
      verifiedAt.hashCode ^
      createdAt.hashCode;
}
