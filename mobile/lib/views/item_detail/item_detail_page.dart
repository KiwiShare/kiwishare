import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/listing_provider.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/item_repository.dart';
import '../../theme/app_theme.dart';
import 'item_detail_screen.dart';
import 'item_edit_screen.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late Future<ItemModel> _itemFuture;
  var _isDeleting = false;

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

  Future<void> _editItem(ItemModel item) async {
    final updatedItem = await Navigator.of(context).push<ItemModel>(
      MaterialPageRoute(builder: (context) => ItemEditScreen(item: item)),
    );
    if (updatedItem != null && mounted) {
      setState(() => _itemFuture = Future.value(updatedItem));
    }
  }

  Future<void> _deleteItem(ItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: const Text(
          'It will be removed from browse results. Existing trade, report, review, and audit records are retained.',
        ),
        actions: [
          TextButton(
            key: const Key('delete_cancel_button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('delete_confirm_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete listing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final token = context.read<AuthProvider>().jwtToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again to delete this item.'),
        ),
      );
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await context.read<ListingProvider>().deleteItem(
        id: item.id,
        token: token,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      messenger.showSnackBar(const SnackBar(content: Text('Listing deleted.')));
    } on ItemRepositoryException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This listing could not be deleted. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
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

        final item = snapshot.data!;
        final currentUserId = context.watch<AuthProvider>().currentUser?.id;
        final isOwner = currentUserId != null && item.ownerId == currentUserId;
        return ItemDetailScreen(
          item: item,
          onEdit: isOwner ? () => _editItem(item) : null,
          onDelete: isOwner ? () => _deleteItem(item) : null,
          isDeleting: _isDeleting,
        );
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
