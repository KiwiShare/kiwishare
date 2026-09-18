import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../products/product_detail_screen.dart';
import '../shared/widgets/edit_item_sheet.dart';
import '../shared/widgets/item_card.dart';

enum UserListingsMode { selling, sold }

class UserListingsScreen extends StatefulWidget {
  const UserListingsScreen({super.key, required this.mode});
  final UserListingsMode mode;

  @override
  State<UserListingsScreen> createState() => _UserListingsScreenState();
}

class _UserListingsScreenState extends State<UserListingsScreen> {
  String? _token;
  Future<List<ItemModel>>? _items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthProvider>().jwtToken;
    if (token != _token) {
      _token = token;
      _load();
    }
  }

  void _load() {
    final token = _token;
    _items = token == null
        ? null
        : context.read<ListingProvider>().getMyItems(
            sold: widget.mode == UserListingsMode.sold,
            token: token,
          );
  }

  @override
  Widget build(BuildContext context) {
    final sold = widget.mode == UserListingsMode.sold;
    final token = _token;
    return Scaffold(
      appBar: AppBar(
        title: Text(sold ? 'Sold' : 'Selling'),
        actions: [
          if (token != null)
            IconButton(
              tooltip: 'Refresh listings',
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: token == null
          ? const _ListingsMessage(
              icon: Icons.lock_outline,
              title: 'Please log in',
              message: 'Log in to view your listings.',
            )
          : FutureBuilder<List<ItemModel>>(
              key: ValueKey(token),
              future: _items,
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
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ItemCard(
                            item: item,
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(
                                        itemId: item.id,
                                        item: item,
                                      ),
                                    ),
                                  )
                                  .then((_) => setState(_load));
                            },
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.white.withOpacity(0.9),
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () async {
                                final updated = await EditItemSheet.show(
                                  context,
                                  item: item,
                                );
                                if (updated != null) {
                                  setState(_load);
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
