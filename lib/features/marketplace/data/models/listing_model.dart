import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/listing.dart';

/// Extension model for the [Listing] domain entity to handle serialization.
class ListingModel extends Listing {
  const ListingModel({
    required super.id,
    required super.sellerId,
    required super.title,
    required super.description,
    required super.category,
    required super.cost,
    super.imageUrl,
    super.status,
    super.isFlagged,
    super.buyerId,
    super.verifiedAt,
    required super.createdAt,
  });

  /// Maps a Firestore document or API JSON map to the [ListingModel] entity.
  factory ListingModel.fromMap(String id, Map<String, dynamic> map) {
    return ListingModel(
      id: id,
      sellerId: map['seller_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: _parseCategory(map['category'] as String?),
      cost: (map['cost'] as num? ?? 0.0).toDouble(),
      imageUrl: map['image_url'] as String?,
      status: _parseStatus(map['status'] as String?),
      isFlagged: map['is_flagged'] as bool? ?? false,
      buyerId: map['buyer_id'] as String?,
      verifiedAt: map['verified_at'] != null ? parseTimestamp(map['verified_at']) : null,
      createdAt: parseTimestamp(map['created_at']),
    );
  }

  /// Converts the [Listing] entity into a Firestore-ready update map.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'seller_id': sellerId,
      'title': title,
      'description': description,
      'category': category.name,
      'cost': cost,
      'image_url': imageUrl,
      'status': status.name,
      'is_flagged': isFlagged,
      'buyer_id': buyerId,
      'verified_at': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  /// Converts the [Listing] entity into a standard JSON map (useful for mock/dev backend).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'seller_id': sellerId,
      'title': title,
      'description': description,
      'category': category.name,
      'cost': cost,
      'image_url': imageUrl,
      'status': status.name,
      'is_flagged': isFlagged,
      'buyer_id': buyerId,
      'verified_at': verifiedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static ListingCategory _parseCategory(String? value) {
    if (value == null) return ListingCategory.other;
    final lower = value.toLowerCase();
    return ListingCategory.values.firstWhere(
      (ListingCategory e) => e.name.toLowerCase() == lower,
      orElse: () => ListingCategory.other,
    );
  }

  static ListingStatus _parseStatus(String? value) {
    if (value == null) return ListingStatus.active;
    final lower = value.toLowerCase();
    return ListingStatus.values.firstWhere(
      (ListingStatus e) => e.name.toLowerCase() == lower,
      orElse: () => ListingStatus.active,
    );
  }

  /// Safe helper to parse varied timestamp formats into UTC [DateTime].
  static DateTime parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return DateTime.now().toUtc();
  }
}
