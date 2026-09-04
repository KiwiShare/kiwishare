import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../shared/widgets/item_card.dart';

enum UserListingsMode { selling, sold }

class UserListingsScreen extends StatelessWidget {
  const UserListingsScreen({super.key, required this.mode});
  final UserListingsMode mode;

  @override
  Widget build(BuildContext context) {
    final sold = mode == UserListingsMode.sold;
    final token = context.read<AuthProvider>().jwtToken;
    return Scaffold(
      appBar: AppBar(title: Text(sold ? 'Sold' : 'Selling')),
      body: token == null
          ? const _ListingsMessage(
              icon: Icons.lock_outline,
              title: 'Please log in',
              message: 'Log in to view your listings.',
            )
          : FutureBuilder<List<ItemModel>>(
              future: context.read<ListingProvider>().getMyItems(
                sold: sold,
                token: token,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const _ListingsMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load your listings',
                    message: 'Check your connection and try again.',
                  );
                }
                final items = snapshot.data ?? const <ItemModel>[];
                if (items.isEmpty) {
                  return _ListingsMessage(
                    icon: sold
                        ? Icons.inventory_2_outlined
                        : Icons.sell_outlined,
                    title: sold
                        ? 'You haven’t sold anything yet'
                        : 'You have no active listings',
                    message: sold
                        ? 'Completed sales will appear here.'
                        : 'Items you list for sale will appear here.',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.76,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => ItemCard(item: items[index]),
                );
              },
            ),
    );
  }
}

class _ListingsMessage extends StatelessWidget {
  const _ListingsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
