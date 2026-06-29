import 'package:meta/meta.dart';

/// Sealed hierarchy for errors occurring in the Marketplace feature.
@immutable
sealed class MarketplaceFailure {
  final String message;
  const MarketplaceFailure(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested listing does not exist in the store.
class ListingNotFound extends MarketplaceFailure {
  const ListingNotFound([String message = 'Listing not found']) : super(message);
}

/// Thrown when a user tries to edit, delete, or generate QR for a listing they do not own.
class PermissionDenied extends MarketplaceFailure {
  const PermissionDenied([String message = 'You do not have permission to perform this action']) : super(message);
}

/// Thrown when cost is invalid (e.g. less than zero).
class InvalidCost extends MarketplaceFailure {
  const InvalidCost([String message = 'Cost must be greater than or equal to 0.00']) : super(message);
}

/// Thrown when a QR payload contains invalid data or campus mismatch.
class QrVerificationFailed extends MarketplaceFailure {
  const QrVerificationFailed([String message = 'QR verification failed: payload mismatch or invalid code']) : super(message);
}

/// Thrown when the QR code's generatedAt timestamp is older than 15 minutes.
class QrExpired extends MarketplaceFailure {
  const QrExpired([String message = 'QR verification failed: QR code has expired']) : super(message);
}

/// Thrown if verifyHandshake is run on a listing that isn't active (e.g. already sold/pending).
class ListingAlreadySold extends MarketplaceFailure {
  const ListingAlreadySold([String message = 'Listing is already sold, pending, or cancelled']) : super(message);
}

/// General fallback failure.
class MarketplaceUnknown extends MarketplaceFailure {
  const MarketplaceUnknown([String message = 'An unknown marketplace error occurred']) : super(message);
}

// ── Result Type ───────────────────────────────────────────────────────────

/// Discriminated result type for all marketplace operations.
sealed class MarketResult<T> {
  const MarketResult();
}

/// The marketplace operation completed successfully.
final class MarketSuccess<T> extends MarketResult<T> {
  final T value;
  const MarketSuccess(this.value);
}

/// The marketplace operation failed with a typed [MarketplaceFailure].
final class MarketFailed<T> extends MarketResult<T> {
  final MarketplaceFailure failure;
  const MarketFailed(this.failure);
}

