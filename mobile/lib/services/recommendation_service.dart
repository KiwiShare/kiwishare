import '../models/discovery_options_model.dart';
import '../models/item_model.dart';
import '../repositories/item_repository.dart';

/// Central recommendation module used by Home and product detail.
///
/// It owns the recommendation surfaces so ranking-related fetch/fallback logic
/// does not drift between screens.
class RecommendationService {
  RecommendationService(this._itemRepository);

  final ItemRepository _itemRepository;

  List<ItemModel>? _featuredCache;
  final Map<String, List<ItemModel>> _forYouCache = {};
  final Map<String, List<ItemModel>> _similarCache = {};

  Future<List<ItemModel>> featured({
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _featuredCache != null) {
      return _featuredCache!.take(limit).toList(growable: false);
    }
    final items = await _itemRepository.fetchFeaturedItems(limit: limit);
    _featuredCache = items;
    return items;
  }

  Future<List<ItemModel>> forYou({
    int limit = 10,
    double? latitude,
    double? longitude,
    String? token,
    bool forceRefresh = false,
  }) async {
    final key = [
      limit,
      latitude?.toStringAsFixed(3) ?? '',
      longitude?.toStringAsFixed(3) ?? '',
      token?.isNotEmpty == true ? 'signed-in' : 'guest',
    ].join(':');
    if (!forceRefresh && _forYouCache[key] != null) {
      return _forYouCache[key]!;
    }
    final items = await _itemRepository.fetchRecommendedItems(
      limit: limit,
      latitude: latitude,
      longitude: longitude,
      token: token,
    );
    _forYouCache[key] = items;
    return items;
  }

  Future<List<ItemModel>> similarTo(
    ItemModel currentItem, {
    int limit = 6,
    String? token,
    bool forceRefresh = false,
  }) async {
    final key = '${currentItem.id}:$limit:${token?.isNotEmpty == true}';
    if (!forceRefresh && _similarCache[key] != null) {
      return _similarCache[key]!;
    }

    final result = <ItemModel>[];
    final seen = <String>{currentItem.id};

    if (currentItem.category.trim().isNotEmpty) {
      try {
        final sameCategory = await _itemRepository.fetchDiscoveryItems(
          DiscoveryQuery(category: currentItem.category),
        );
        for (final item in sameCategory) {
          if (seen.add(item.id)) result.add(item);
          if (result.length >= limit) break;
        }
      } catch (_) {
        // Recommendation surfaces fail softly; the fallback below can still
        // populate the section.
      }
    }

    if (result.length < limit) {
      try {
        final recommended = await _itemRepository.fetchRecommendedItems(
          limit: limit * 2,
          token: token,
        );
        for (final item in recommended) {
          if (seen.add(item.id)) result.add(item);
          if (result.length >= limit) break;
        }
      } catch (_) {
        // Keep any same-category results already collected.
      }
    }

    final items = result.take(limit).toList(growable: false);
    _similarCache[key] = items;
    return items;
  }

  void invalidate() {
    _featuredCache = null;
    _forYouCache.clear();
    _similarCache.clear();
  }
}
