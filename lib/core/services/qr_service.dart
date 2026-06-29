import 'dart:convert';

/// Service for generating and validating QR codes for peer-to-peer transaction handshake.
class QrService {
  /// The mandatory campus code required for all payloads.
  static const String expectedCampusCode = 'CAM-AUS-11';

  /// Generates a JSON-encoded string payload for a given listing and seller.
  /// Encodes the current UTC timestamp as [generatedAt].
  String generatePayload({
    required String listingId,
    required String sellerId,
    DateTime? mockTime,
  }) {
    final timestamp = mockTime ?? DateTime.now().toUtc();
    final data = {
      'listingId': listingId,
      'sellerId': sellerId,
      'campusCode': expectedCampusCode,
      'generatedAt': timestamp.toIso8601String(),
    };
    return jsonEncode(data);
  }

  /// Verifies a QR payload matches the expected listing and seller.
  /// Enforces:
  /// 1. valid JSON syntax
  /// 2. matching [listingId]
  /// 3. matching [sellerId]
  /// 4. campusCode matches 'CAM-AUS-11'
  /// 5. payload was generated <= 15 minutes ago
  bool verifyPayload({
    required String payload,
    required String listingId,
    required String sellerId,
    DateTime? mockTime,
  }) {
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      
      final payloadListingId = decoded['listingId'] as String?;
      final payloadSellerId = decoded['sellerId'] as String?;
      final payloadCampusCode = decoded['campusCode'] as String?;
      final payloadGeneratedAtStr = decoded['generatedAt'] as String?;

      if (payloadListingId != listingId) return false;
      if (payloadSellerId != sellerId) return false;
      if (payloadCampusCode != expectedCampusCode) return false;
      if (payloadGeneratedAtStr == null) return false;

      final generatedAt = DateTime.parse(payloadGeneratedAtStr).toUtc();
      final now = mockTime ?? DateTime.now().toUtc();
      
      final difference = now.difference(generatedAt);
      // Ensure difference is positive (not in future) and less than or equal to 15 minutes
      if (difference.inSeconds < 0 || difference.inMinutes > 15) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Helper specifically for throwing/categorizing failure types during validation.
  /// Returns null on success, otherwise returns a message/type code or just the error.
  String? validatePayloadReason({
    required String payload,
    required String listingId,
    required String sellerId,
    DateTime? mockTime,
  }) {
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      
      final payloadListingId = decoded['listingId'] as String?;
      final payloadSellerId = decoded['sellerId'] as String?;
      final payloadCampusCode = decoded['campusCode'] as String?;
      final payloadGeneratedAtStr = decoded['generatedAt'] as String?;

      if (payloadListingId != listingId || payloadSellerId != sellerId) {
        return 'mismatch';
      }
      if (payloadCampusCode != expectedCampusCode) {
        return 'campus_mismatch';
      }
      if (payloadGeneratedAtStr == null) {
        return 'mismatch';
      }

      final generatedAt = DateTime.parse(payloadGeneratedAtStr).toUtc();
      final now = mockTime ?? DateTime.now().toUtc();
      final difference = now.difference(generatedAt);

      if (difference.inSeconds < 0 || difference.inMinutes > 15) {
        return 'expired';
      }

      return null;
    } catch (_) {
      return 'invalid_format';
    }
  }
}
