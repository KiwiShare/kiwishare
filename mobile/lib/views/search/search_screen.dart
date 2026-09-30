import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/discovery_options_model.dart';
import '../../models/item_model.dart';
import '../../providers/providers.dart';
import '../../widgets/resilient_network_image.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;

  late ListingProvider _listingProvider;
  late SearchProvider _searchProvider;

  bool _initialized = false;
  bool _showResults = false;
  String _submittedQuery = '';
  Future<List<String>>? _suggestionsFuture;
  Future<List<ItemModel>>? _resultsFuture;
  DiscoveryOptionsModel? _options;

  String? _category;
  String? _location;
  double? _minimumPrice;
  double? _maximumPrice;
  bool _sustainableOnly = false;
  String _sort = 'recommended';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery.trim());
    _focusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _listingProvider = context.read<ListingProvider>();
    _searchProvider = context.read<SearchProvider>();
    unawaited(_searchProvider.loadRecentSearches());

    _suggestionsFuture = _listingProvider.getSearchSuggestions(
      _controller.text.trim(),
    );
    unawaited(
      _listingProvider.getDiscoveryOptions().then((value) {
        if (!mounted) return;
        setState(() => _options = value);
      }),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.text.trim().isNotEmpty) {
        _submitSearch(_controller.text);
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _onQueryChanged(String value) {
    if (_showResults) {
      setState(() => _showResults = false);
    } else {
      setState(() {});
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _suggestionsFuture = _listingProvider.getSearchSuggestions(
          value.trim(),
        );
      });
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _showResults = false;
      _submittedQuery = '';
      _suggestionsFuture = _listingProvider.getSearchSuggestions('');
    });
    _focusNode.requestFocus();
  }

  DiscoveryQuery _buildQuery() {
    return DiscoveryQuery(
      query: _submittedQuery,
      category: _category,
      location: _location,
      minimumPrice: _minimumPrice,
      maximumPrice: _maximumPrice,
      sustainableOnly: _sustainableOnly,
      sort: _sort,
    );
  }

  void _refreshResults() {
    if (_submittedQuery.isEmpty) return;
    setState(() {
      _resultsFuture = _listingProvider.getDiscoveryItems(
        query: _buildQuery(),
        forceRefresh: true,
      );
    });
  }

  void _submitSearch(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    _debounce?.cancel();
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _focusNode.unfocus();
    unawaited(_searchProvider.addRecentSearch(query));

    setState(() {
      _submittedQuery = query;
      _showResults = true;
      _resultsFuture = _listingProvider.getDiscoveryItems(
        query: _buildQuery(),
        forceRefresh: true,
      );
    });
  }

  void _setSort(String sort) {
    if (_sort == sort) return;
    _sort = sort;
    _refreshResults();
  }

  void _togglePriceSort() {
    _sort = _sort == 'price_asc' ? 'price_desc' : 'price_asc';
    _refreshResults();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_category != null) count++;
    if (_location != null) count++;
    if (_minimumPrice != null || _maximumPrice != null) count++;
    if (_sustainableOnly) count++;
    return count;
  }

  Future<void> _openFilters({bool locationOnly = false}) async {
    final result = await showModalBottomSheet<_SearchFilterValues>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchFilterSheet(
        options: _options,
        locationOnly: locationOnly,
        initial: _SearchFilterValues(
          category: _category,
          location: _location,
          minimumPrice: _minimumPrice,
          maximumPrice: _maximumPrice,
          sustainableOnly: _sustainableOnly,
        ),
      ),
    );
    if (result == null) return;

    _category = result.category;
    _location = result.location;
    _minimumPrice = result.minimumPrice;
    _maximumPrice = result.maximumPrice;
    _sustainableOnly = result.sustainableOnly;
    _refreshResults();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              controller: _controller,
              focusNode: _focusNode,
              onBack: _goBack,
              onChanged: _onQueryChanged,
              onSubmitted: _submitSearch,
              onClear: _clearQuery,
            ),
            if (_showResults) ...[
              _SearchResultFilters(
                sort: _sort,
                activeFilterCount: _activeFilterCount,
                location: _location,
                onRecommended: () => _setSort('recommended'),
                onPrice: _togglePriceSort,
                onNewest: () => _setSort('newest'),
                onLocation: () => _openFilters(locationOnly: true),
                onFilters: _openFilters,
              ),
              Expanded(child: _buildResults()),
            ] else
              Expanded(child: _buildSearchDiscovery()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchDiscovery() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return _SearchLanding(
        suggestionsFuture: _suggestionsFuture,
        fallbackSuggestions:
            _options?.categories
                .map((entry) => entry.value)
                .take(10)
                .toList() ??
            const <String>[],
        onSearch: _submitSearch,
      );
    }

    return FutureBuilder<List<String>>(
      future: _suggestionsFuture,
      builder: (context, snapshot) {
        final suggestions = snapshot.data ?? const <String>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            suggestions.isEmpty) {
          return const _SearchSuggestionSkeleton();
        }
        if (suggestions.isEmpty) {
          return _SearchNoSuggestions(
            query: query,
            onSearch: () => _submitSearch(query),
          );
        }
        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return _SearchSuggestionRow(
              suggestion: suggestion,
              query: query,
              onTap: () => _submitSearch(suggestion),
            );
          },
        );
      },
    );
  }

  Widget _buildResults() {
    return FutureBuilder<List<ItemModel>>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SearchResultsSkeleton();
        }
        if (snapshot.hasError) {
          return _SearchResultsError(onRetry: _refreshResults);
        }

        final items = snapshot.data ?? const <ItemModel>[];
        if (items.isEmpty) {
          return _SearchEmptyResults(
            query: _submittedQuery,
            onEditSearch: () {
              setState(() => _showResults = false);
              _focusNode.requestFocus();
            },
            onResetFilters: () {
              _category = null;
              _location = null;
              _minimumPrice = null;
              _maximumPrice = null;
              _sustainableOnly = false;
              _sort = 'recommended';
              _refreshResults();
            },
          );
        }

        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${items.length} result${items.length == 1 ? '' : 's'} across KiwiShare',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            final item = items[index - 1];
            return _SearchResultTile(
              item: item,
              onTap: () => context.push('/items/${item.id}', extra: item),
            );
          },
        );
      },
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onBack,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        children: [
          IconButton(
            key: const Key('search-back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
            tooltip: 'Back',
          ),
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                key: const Key('search-input'),
                controller: controller,
                focusNode: focusNode,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  hintText: 'Search all KiwiShare',
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('search-clear'),
                          onPressed: onClear,
                          icon: const Icon(Icons.cancel_rounded, size: 20),
                          tooltip: 'Clear search',
                        ),
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: colors.outline.withValues(alpha: 0.72),
                      width: 1.35,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: colors.primary, width: 1.8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('search-submit'),
            onPressed: () => onSubmitted(controller.text),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchLanding extends StatelessWidget {
  final Future<List<String>>? suggestionsFuture;
  final List<String> fallbackSuggestions;
  final ValueChanged<String> onSearch;

  const _SearchLanding({
    required this.suggestionsFuture,
    required this.fallbackSuggestions,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        if (provider.recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Recent searches',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                key: const Key('search-clear-history'),
                onPressed: () => provider.clearRecentSearches(),
                icon: const Icon(Icons.delete_outline_rounded, size: 21),
                tooltip: 'Clear recent searches',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final query in provider.recentSearches)
                ActionChip(
                  label: Text(query),
                  onPressed: () => onSearch(query),
                  backgroundColor: colors.surfaceContainerLow,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
        ],
        Row(
          children: [
            Text(
              'Try searching for',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 19),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<String>>(
          future: suggestionsFuture,
          builder: (context, snapshot) {
            final remote = snapshot.data ?? const <String>[];
            final suggestions = remote.isNotEmpty
                ? remote
                : fallbackSuggestions;
            if (snapshot.connectionState == ConnectionState.waiting &&
                suggestions.isEmpty) {
              return const _TrendingSkeleton();
            }
            if (suggestions.isEmpty) {
              return Text(
                'Start typing to search listings, categories and locations.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in suggestions.take(10))
                  ActionChip(
                    label: Text(suggestion),
                    avatar: const Icon(Icons.search_rounded, size: 17),
                    onPressed: () => onSearch(suggestion),
                    backgroundColor: colors.surfaceContainerLow,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SearchSuggestionRow extends StatelessWidget {
  final String suggestion;
  final String query;
  final VoidCallback onTap;

  const _SearchSuggestionRow({
    required this.suggestion,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lowerSuggestion = suggestion.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final start = lowerSuggestion.indexOf(lowerQuery);

    TextSpan label;
    if (start < 0 || query.isEmpty) {
      label = TextSpan(text: suggestion);
    } else {
      label = TextSpan(
        children: [
          if (start > 0) TextSpan(text: suggestion.substring(0, start)),
          TextSpan(
            text: suggestion.substring(start, start + query.length),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (start + query.length < suggestion.length)
            TextSpan(text: suggestion.substring(start + query.length)),
        ],
      );
    }

    return ListTile(
      minLeadingWidth: 24,
      leading: const Icon(Icons.search_rounded, size: 23),
      title: Text.rich(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurface, fontSize: 16),
      ),
      trailing: Icon(
        Icons.north_west_rounded,
        size: 18,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _SearchResultFilters extends StatelessWidget {
  final String sort;
  final int activeFilterCount;
  final String? location;
  final VoidCallback onRecommended;
  final VoidCallback onPrice;
  final VoidCallback onNewest;
  final VoidCallback onLocation;
  final VoidCallback onFilters;

  const _SearchResultFilters({
    required this.sort,
    required this.activeFilterCount,
    required this.location,
    required this.onRecommended,
    required this.onPrice,
    required this.onNewest,
    required this.onLocation,
    required this.onFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget button({
      required String label,
      required VoidCallback onTap,
      bool active = false,
      Widget? suffix,
    }) {
      return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: active ? colors.primary : colors.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          minimumSize: Size.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (suffix != null) ...[const SizedBox(width: 2), suffix],
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          children: [
            button(
              label: 'Recommended',
              onTap: onRecommended,
              active: sort == 'recommended',
            ),
            button(
              label: 'Price',
              onTap: onPrice,
              active: sort == 'price_asc' || sort == 'price_desc',
              suffix: Icon(
                sort == 'price_desc'
                    ? Icons.arrow_downward_rounded
                    : Icons.unfold_more_rounded,
                size: 15,
              ),
            ),
            button(label: 'Newest', onTap: onNewest, active: sort == 'newest'),
            button(
              label: location ?? 'Location',
              onTap: onLocation,
              active: location != null,
              suffix: const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
            ),
            button(
              label: activeFilterCount == 0
                  ? 'Filters'
                  : 'Filters $activeFilterCount',
              onTap: onFilters,
              active: activeFilterCount > 0,
              suffix: const Icon(Icons.tune_rounded, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const _SearchResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sellerName = item.seller?.displayName.trim().isNotEmpty == true
        ? item.seller!.displayName.trim()
        : 'Kiwi Seller';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 132,
                height: 132,
                child: item.imageUrl.isEmpty
                    ? ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : ResilientNetworkImage(
                        url: item.imageUrl,
                        logicalCacheWidth: 300,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: SizedBox(
                height: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.isPromoted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'FEATURED',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    Text(
                      item.title,
                      maxLines: item.isPromoted ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        height: 1.28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${item.category} · ${item.displayLocation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.isFree ? 'FREE' : '\$${item.priceNzd}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sellerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFilterValues {
  final String? category;
  final String? location;
  final double? minimumPrice;
  final double? maximumPrice;
  final bool sustainableOnly;

  const _SearchFilterValues({
    this.category,
    this.location,
    this.minimumPrice,
    this.maximumPrice,
    this.sustainableOnly = false,
  });
}

class _SearchFilterSheet extends StatefulWidget {
  final DiscoveryOptionsModel? options;
  final _SearchFilterValues initial;
  final bool locationOnly;

  const _SearchFilterSheet({
    required this.options,
    required this.initial,
    required this.locationOnly,
  });

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late String? _category;
  late String? _location;
  late bool _sustainableOnly;
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;

  @override
  void initState() {
    super.initState();
    _category = widget.initial.category;
    _location = widget.initial.location;
    _sustainableOnly = widget.initial.sustainableOnly;
    _minimumController = TextEditingController(
      text: widget.initial.minimumPrice?.toString() ?? '',
    );
    _maximumController = TextEditingController(
      text: widget.initial.maximumPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).pop(
      _SearchFilterValues(
        category: _category,
        location: _location,
        minimumPrice: double.tryParse(_minimumController.text.trim()),
        maximumPrice: double.tryParse(_maximumController.text.trim()),
        sustainableOnly: _sustainableOnly,
      ),
    );
  }

  void _reset() {
    setState(() {
      if (widget.locationOnly) {
        _location = null;
      } else {
        _category = null;
        _location = null;
        _minimumController.clear();
        _maximumController.clear();
        _sustainableOnly = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final categories =
        widget.options?.categories.map((entry) => entry.value).toList() ??
        const <String>[];
    final locations =
        widget.options?.locations.map((entry) => entry.value).toList() ??
        const <String>[];

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      widget.locationOnly ? 'Location' : 'Search filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(onPressed: _reset, child: const Text('Reset')),
                  ],
                ),
                const SizedBox(height: 14),
                if (!widget.locationOnly) ...[
                  DropdownButtonFormField<String>(
                    key: const Key('search-filter-category'),
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      for (final value in categories)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  const SizedBox(height: 14),
                ],
                DropdownButtonFormField<String>(
                  key: const Key('search-filter-location'),
                  initialValue: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All New Zealand'),
                    ),
                    for (final value in locations)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => setState(() => _location = value),
                ),
                if (!widget.locationOnly) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('search-filter-min-price'),
                          controller: _minimumController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Min price',
                            prefixText: '\$',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('search-filter-max-price'),
                          controller: _maximumController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Max price',
                            prefixText: '\$',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sustainable listings only'),
                    subtitle: const Text(
                      'Show items marked for reuse or lower-waste choices.',
                    ),
                    value: _sustainableOnly,
                    onChanged: (value) =>
                        setState(() => _sustainableOnly = value),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('search-apply-filters'),
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchSuggestionSkeleton extends StatelessWidget {
  const _SearchSuggestionSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      padding: const EdgeInsets.only(top: 10),
      itemCount: 7,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
      itemBuilder: (_, index) => ListTile(
        leading: const Icon(Icons.search_rounded),
        title: FractionallySizedBox(
          widthFactor: 0.45 + (index % 3) * 0.12,
          alignment: Alignment.centerLeft,
          child: Container(height: 14, color: color),
        ),
      ),
    );
  }
}

class _TrendingSkeleton extends StatelessWidget {
  const _TrendingSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        6,
        (index) => Container(
          width: 84 + (index % 3) * 18,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _SearchResultsSkeleton extends StatelessWidget {
  const _SearchResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => Row(
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 15, color: color),
                const SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Container(height: 15, color: color),
                ),
                const SizedBox(height: 42),
                FractionallySizedBox(
                  widthFactor: 0.35,
                  child: Container(height: 19, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchNoSuggestions extends StatelessWidget {
  final String query;
  final VoidCallback onSearch;

  const _SearchNoSuggestions({required this.query, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 42),
            const SizedBox(height: 12),
            Text('Search for “$query”'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onSearch, child: const Text('Search')),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsError extends StatelessWidget {
  final VoidCallback onRetry;

  const _SearchResultsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 46),
            const SizedBox(height: 12),
            const Text('Could not load search results.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmptyResults extends StatelessWidget {
  final String query;
  final VoidCallback onEditSearch;
  final VoidCallback onResetFilters;

  const _SearchEmptyResults({
    required this.query,
    required this.onEditSearch,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'No matches for “$query”',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Try another keyword or broaden your filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: onEditSearch,
                  child: const Text('Edit search'),
                ),
                FilledButton(
                  onPressed: onResetFilters,
                  child: const Text('Reset filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
