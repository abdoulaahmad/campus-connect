import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/listing.dart';
import '../../domain/failures/marketplace_failure.dart';
import '../providers/marketplace_providers.dart';

/// Screen displaying complete details of a marketplace listing.
class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;

  const ListingDetailScreen({
    super.key,
    required this.listingId,
  });

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _isDeleting = false;

  Future<void> _deleteListing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Listing', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this listing? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF00B0FF))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isDeleting = true);
      final actions = ref.read(marketplaceActionsProvider);
      final result = await actions.deleteListing(listingId: widget.listingId);

      if (mounted) {
        setState(() => _isDeleting = false);
        switch (result) {
          case MarketSuccess<void>():
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Listing deleted successfully.'),
                backgroundColor: Colors.green,
              ),
            );
            ref.invalidate(listingsStreamProvider(null));
            context.go('/marketplace');
            break;
          case MarketFailed<void>(:final failure):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure.message),
                backgroundColor: Colors.redAccent,
              ),
            );
            break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUserId = (authState is AuthAuthenticated) ? authState.user.id : null;

    final detailAsync = ref.watch(listingDetailsProvider(widget.listingId));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Listing Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF880E4F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (detailAsync.value is MarketSuccess<Listing> &&
              (detailAsync.value as MarketSuccess<Listing>).value.sellerId == currentUserId &&
              !_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteListing,
            )
        ],
      ),
      body: _isDeleting
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B0FF)),
              ),
            )
          : detailAsync.when(
              data: (result) {
                switch (result) {
                  case MarketFailed<Listing>(:final failure):
                    return Center(
                      child: Text(
                        failure.message,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                    );

                  case MarketSuccess<Listing>(:final value):
                    final isSeller = value.sellerId == currentUserId;
                    final qrService = ref.watch(qrServiceProvider);
                    
                    // Generate payload for QR if seller
                    final qrPayload = isSeller
                        ? qrService.generatePayload(listingId: value.id, sellerId: value.sellerId)
                        : '';

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Item Image / Placeholder
                          AspectRatio(
                            aspectRatio: 1.5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: value.imageUrl != null && value.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      value.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _buildImagePlaceholder(value.category),
                                    )
                                  : _buildImagePlaceholder(value.category),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title and Status Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      value.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      value.category.name.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF00B0FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(value.status),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Price
                          Text(
                            '₦${value.cost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF00B0FF),
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Description Section
                          const Text(
                            'Description',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            value.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Handshake Workflows (Seller QR vs Buyer Scan)
                          if (isSeller) ...[
                            _buildSellerQrSection(qrPayload, value.status),
                          ] else ...[
                            _buildBuyerScanSection(value),
                          ],
                        ],
                      ),
                    );
                }
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B0FF)),
                ),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
    );
  }

  Widget _buildSellerQrSection(String payload, ListingStatus status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const Text(
            'Your Verification QR Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Show this QR code to the buyer to complete the sale. This code is valid for 15 minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 24),
          if (status == ListingStatus.active) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 180.0,
              ),
            ),
          ] else ...[
            Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  status == ListingStatus.pending ? 'Transaction Pending' : 'Sold',
                  style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBuyerScanSection(Listing listing) {
    if (listing.status != ListingStatus.active) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.white60),
            const SizedBox(width: 8),
            Text(
              listing.status == ListingStatus.pending
                  ? 'Purchase is pending verification.'
                  : 'This item has been sold.',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => context.push('/marketplace/${listing.id}/scan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B0FF),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
          label: const Text(
            'Scan to Buy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ListingStatus status) {
    Color color;
    switch (status) {
      case ListingStatus.active:
        color = Colors.blueAccent;
        break;
      case ListingStatus.pending:
        color = Colors.orangeAccent;
        break;
      case ListingStatus.sold:
        color = Colors.green;
        break;
      case ListingStatus.cancelled:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(ListingCategory category) {
    IconData icon;
    switch (category) {
      case ListingCategory.books:
        icon = Icons.menu_book;
        break;
      case ListingCategory.electronics:
        icon = Icons.devices;
        break;
      case ListingCategory.clothing:
        icon = Icons.checkroom;
        break;
      case ListingCategory.services:
        icon = Icons.build_circle;
        break;
      case ListingCategory.other:
        icon = Icons.shopping_bag;
        break;
    }
    return Container(
      color: Colors.white.withOpacity(0.04),
      child: Center(
        child: Icon(
          icon,
          size: 64,
          color: Colors.white.withOpacity(0.15),
        ),
      ),
    );
  }
}
