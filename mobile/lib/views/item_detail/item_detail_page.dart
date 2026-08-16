import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/listing_provider.dart';
import '../../repositories/item_repository.dart';
import '../../theme/app_theme.dart';
import 'item_detail_screen.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late Future<ItemModel> _itemFuture;

  @override
  void initState() {
    super.initState();
    _itemFuture = _loadItem();
  }

  Future<ItemModel> _loadItem() =>
      context.read<ListingProvider>().getItemById(widget.itemId);

  void _retry() {
    setState(() => _itemFuture = _loadItem());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ItemModel>(
      future: _itemFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _DetailStateScaffold(
            child: CircularProgressIndicator(
              key: Key('detail_loading_indicator'),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          final error = snapshot.error;
          final message = error is ItemRepositoryException
              ? error.message
              : 'We could not load this item. Check your connection and try again.';
          return _DetailStateScaffold(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.brandSecondary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Item unavailable',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  key: const Key('detail_error_message'),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (error is! ItemNotFoundException) ...[
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    key: const Key('detail_retry_button'),
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          );
        }

        return ItemDetailScreen(item: snapshot.data!);
      },
    );
  }
}

class _DetailStateScaffold extends StatelessWidget {
  const _DetailStateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      title: const Text('Item details'),
    ),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: child,
        ),
      ),
    ),
  );
}
