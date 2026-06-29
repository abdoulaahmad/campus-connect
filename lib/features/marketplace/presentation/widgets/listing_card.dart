import 'package:flutter/material.dart';
import '../../domain/entities/listing.dart';

/// Reusable listing card for the marketplace grid.
class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;

  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF1E1E1E);

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section with Category Overlay
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.1,
                  child: listing.imageUrl != null && listing.imageUrl!.isNotEmpty
                      ? Image.network(
                          listing.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      listing.category.name.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF00B0FF),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                if (listing.status != ListingStatus.active)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: listing.status == ListingStatus.sold
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        listing.status.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Text Details Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Price tag row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₦${listing.cost.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF00B0FF),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white.withOpacity(0.4),
                        size: 20,
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    IconData icon;
    switch (listing.category) {
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
          size: 40,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }
}
