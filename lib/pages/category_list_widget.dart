import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/vendor_card.dart';
import '../services/vendor_card_service.dart';
import 'vendor_card_form_page.dart';

/// Widget that displays a list of vendor cards owned by the current vendor
class CategoryListWidget extends StatefulWidget {
  const CategoryListWidget({super.key});

  @override
  State<CategoryListWidget> createState() => _CategoryListWidgetState();
}

class _CategoryListWidgetState extends State<CategoryListWidget> {
  final _service = VendorCardService();
  List<VendorCard> _vendorCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVendorCards();
  }

  Future<void> _loadVendorCards() async {
    setState(() => _isLoading = true);
    try {
      final cards = await _service.getVendorCards();
      if (mounted) {
        setState(() {
          _vendorCards = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vendor cards: $e')),
        );
      }
    }
  }

  Future<void> _deleteVendorCard(VendorCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor Card'),
        content: Text(
          'Are you sure you want to delete "${card.studioName}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _service.deleteVendorCard(card.id!);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vendor card deleted successfully')),
          );
          _loadVendorCards();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete vendor card')),
          );
        }
      }
    }
  }

  void _navigateToAddCard() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VendorCardFormPage()),
    );
    if (result == true) {
      _loadVendorCards();
    }
  }

  void _navigateToEditCard(VendorCard card) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VendorCardFormPage(existingCard: card)),
    );
    if (result == true) {
      _loadVendorCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadVendorCards,
      color: const Color(0xff0c1c2c),
      child: Column(
        children: [
          // Header with Add button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Vendor Cards',
                  style: GoogleFonts.urbanist(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _navigateToAddCard,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Card'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0c1c2c),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Vendor card list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _vendorCards.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _vendorCards.length,
                    itemBuilder: (context, index) =>
                        _buildVendorCardWidget(_vendorCards[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        const Icon(
          Icons.card_membership_outlined,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          'No vendor cards yet',
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap "Add Card" to create your first vendor card',
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          'Pull down to refresh',
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildVendorCardWidget(VendorCard card) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              _service.getImageUrl(card.imagePath),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error, size: 50, color: Colors.grey),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Studio Name and Menu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        card.studioName,
                        style: GoogleFonts.urbanist(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _navigateToEditCard(card);
                        } else if (value == 'delete') {
                          _deleteVendorCard(card);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Category and City
                Row(
                  children: [
                    Icon(Icons.category, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      card.categoryName,
                      style: GoogleFonts.urbanist(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.location_city,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      card.city,
                      style: GoogleFonts.urbanist(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Prices
                Row(
                  children: [
                    Text(
                      '₹${card.discountedPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${card.originalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${card.discountPercentage}% OFF',
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...card.serviceTags.map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff0c1c2c).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.urbanist(
                            fontSize: 11,
                            color: const Color(0xff0c1c2c),
                          ),
                        ),
                      ),
                    ),
                    ...card.qualityTags.map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.urbanist(
                            fontSize: 11,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
