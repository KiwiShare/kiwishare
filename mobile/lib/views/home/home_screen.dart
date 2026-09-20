import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/nz_locations.dart';
import '../../models/discovery_options_model.dart';
import '../../models/item_model.dart';
import '../../providers/providers.dart';
import '../../services/product_location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kiwishare_logo.dart';
import '../scanner/qr_scanner_screen.dart';
import '../shared/widgets/item_card.dart';
import '../shared/widgets/item_card_skeleton.dart';
import 'widgets/home_filter_sheet.dart';
import 'widgets/home_product_map.dart';

class HomeScreen extends StatefulWidget {
  final ProductLocationService? locationService;
  final ValueChanged<ItemModel>? onOpenItem;
  final bool? autoLocate;

  const HomeScreen({
    super.key,
    this.locationService,
    this.onOpenItem,
    this.autoLocate = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _searchController;
  late final ProductLocationService _locationService;
  late HomeDiscoveryProvider _discovery;
  Future<List<ItemModel>>? _itemsFuture;
  Future<List<ItemModel>>? _featuredFuture;
  Future<List<ItemModel>>? _recommendedFuture;
  Timer? _filterDebounce;
  Object? _optionsError;
  bool _optionsLoading = true;
  DiscoveryQuery? _lastRequestedQuery;
  bool _initialized = false;
  bool _autoLocated = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _locationService = widget.locationService ?? DeviceProductLocationService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final listingProvider = context.read<ListingProvider>();
    _discovery = context.read<HomeDiscoveryProvider>();
    _searchController.text = _discovery.query;
    _lastRequestedQuery = _discovery.discoveryQuery;
    final token = context.read<AuthProvider?>()?.jwtToken;
    _itemsFuture = listingProvider.getDiscoveryItems(
      query: _discovery.discoveryQuery,
    );
    _featuredFuture = listingProvider.getFeaturedItems(limit: 10);
    _recommendedFuture = listingProvider.getRecommendedItems(
      limit: 10,
      latitude: _discovery.userLatitude,
      longitude: _discovery.userLongitude,
      token: token,
    );
    _discovery.addListener(_onDiscoveryChanged);
    _initialized = true;
    unawaited(_loadDiscoveryOptions());
    if ((widget.autoLocate ?? false) && !_autoLocated) {
      _autoLocated = true;
      unawaited(_autoDetectLocation());
    }
  }

  Future<void> _autoDetectLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      context.read<HomeDiscoveryProvider>().setLocation(
        location.city,
        nearYou: true,
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (_) {
      // Silently ignore if permissions are not granted or services are off
    }
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    if (_initialized) _discovery.removeListener(_onDiscoveryChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscoveryOptions({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _optionsLoading = true;
        _optionsError = null;
      });
    }
    try {
      final options = await context.read<ListingProvider>().getDiscoveryOptions(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      _discovery.applyOptions(options);
      setState(() => _optionsLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _optionsLoading = false;
        _optionsError = error;
      });
    }
  }

  void _onDiscoveryChanged() {
    final query = _discovery.discoveryQuery;
    if (query == _lastRequestedQuery) return;
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _lastRequestedQuery = query;
      setState(() {
        _itemsFuture = context.read<ListingProvider>().getDiscoveryItems(
          query: query,
        );
      });
    });
  }

  Future<void> _retryFetch() async {
    _filterDebounce?.cancel();
    final query = _discovery.discoveryQuery;
    final listingProvider = context.read<ListingProvider>();
    _lastRequestedQuery = query;
    final token = context.read<AuthProvider?>()?.jwtToken;
    setState(() {
      _itemsFuture = listingProvider.getDiscoveryItems(
        query: query,
        forceRefresh: true,
      );
      _featuredFuture = listingProvider.getFeaturedItems(
        limit: 10,
        forceRefresh: true,
      );
      _recommendedFuture = listingProvider.getRecommendedItems(
        limit: 10,
        latitude: _discovery.userLatitude,
        longitude: _discovery.userLongitude,
        token: token,
        forceRefresh: true,
      );
    });
    await Future.wait([
      _itemsFuture!,
      if (_featuredFuture != null) _featuredFuture!,
      _recommendedFuture!,
      _loadDiscoveryOptions(forceRefresh: true),
    ]);
  }

  void _openProduct(ItemModel item) {
    final callback = widget.onOpenItem;
    if (callback != null) {
      callback(item);
      return;
    }
    context.push('/items/${item.id}', extra: item);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<HomeDiscoveryProvider>().setQuery('');
  }

  void _resetFilters() {
    _searchController.clear();
    context.read<HomeDiscoveryProvider>().resetFilters();
  }

  void _showFilters() {
    final filters = context.read<HomeDiscoveryProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (_) => HomeFilterSheet(filters: filters, onReset: _resetFilters),
    );
  }

  void _showLocationPicker() {
    final filters = context.read<HomeDiscoveryProvider>()
      ..setView(HomeProductView.map);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: _NzCascadingLocationSheet(
          filters: filters,
          onUseCurrentLocation: _useCurrentLocation,
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      context.read<HomeDiscoveryProvider>()
        ..setLocation(
          location.city,
          nearYou: true,
          latitude: location.latitude,
          longitude: location.longitude,
        )
        ..setView(HomeProductView.map);
    } on ProductLocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = context.watch<HomeDiscoveryProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _retryFetch,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeHeader(
                  location: filters.selectedLocation,
                  nearYou: filters.isNearYou,
                  onChooseLocation: _showLocationPicker,
                  onScanQr: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const QrScannerScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('home-search-field'),
                  controller: _searchController,
                  onChanged: filters.setQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by item name or category',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.brandPrimary,
                    ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 48),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                        IconButton(
                          key: const Key('home-filter-button'),
                          tooltip: 'Sort and filter products',
                          onPressed: _showFilters,
                          color: AppColors.brandPrimary,
                          icon: Badge(
                            isLabelVisible: filters.activeFilterCount > 0,
                            label: Text('${filters.activeFilterCount}'),
                            child: const Icon(Icons.tune),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_optionsLoading)
                  const LinearProgressIndicator(
                    key: Key('home-discovery-options-loading'),
                    minHeight: 2,
                  )
                else if (_optionsError != null)
                  _DiscoveryOptionsError(
                    onRetry: () => _loadDiscoveryOptions(forceRefresh: true),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final category in filters.categories) ...[
                          _HomeCategoryChip(
                            key: Key('home-category-${category.value}'),
                            label: category.value,
                            selected:
                                filters.selectedCategory == category.value,
                            onTap: () => filters.toggleCategory(category.value),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FutureBuilder<List<ItemModel>>(
                  future: _featuredFuture,
                  builder: (context, snapshot) {
                    final featured = snapshot.data ?? const <ItemModel>[];
                    if (featured.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: _HomeJumboCarousel(
                        items: featured,
                        onOpen: _openProduct,
                      ),
                    );
                  },
                ),
                FutureBuilder<List<ItemModel>>(
                  future: _recommendedFuture,
                  builder: (context, snapshot) {
                    final recommended = snapshot.data ?? const <ItemModel>[];
                    if (recommended.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: _HomeRecommendedSection(
                        items: recommended,
                        onOpen: _openProduct,
                      ),
                    );
                  },
                ),
                FutureBuilder<List<ItemModel>>(
                  future: _itemsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _HomeLoadingState();
                    }
                    if (snapshot.hasError) {
                      return _HomeErrorState(onRetry: _retryFetch);
                    }
                    final products = snapshot.data ?? const <ItemModel>[];
                    ItemModel? selectedItem;
                    for (final product in products) {
                      if (product.id == filters.previewItemId) {
                        selectedItem = product;
                        break;
                      }
                    }
                    return _HomeDiscoveryResults(
                      products: products,
                      selectedItem: selectedItem,
                      filters: filters,
                      onShowFilters: _showFilters,
                      onOpenProduct: _openProduct,
                      onLocateMe: _useCurrentLocation,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SustainabilityBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _getCategoryIcon(String category) {
  final normalized = category.toLowerCase().trim();
  if (normalized.contains('furnitur') ||
      normalized.contains('chair') ||
      normalized.contains('table') ||
      normalized.contains('desk')) {
    return Icons.chair_outlined;
  }
  if (normalized.contains('plant') ||
      normalized.contains('garden') ||
      normalized.contains('flower') ||
      normalized.contains('tree')) {
    return Icons.yard_outlined;
  }
  if (normalized.contains('camp') ||
      normalized.contains('outdoor') ||
      normalized.contains('tent') ||
      normalized.contains('hike')) {
    return Icons.forest_outlined;
  }
  if (normalized.contains('elect') ||
      normalized.contains('device') ||
      normalized.contains('phone') ||
      normalized.contains('tech') ||
      normalized.contains('comput')) {
    return Icons.devices_outlined;
  }
  if (normalized.contains('transp') ||
      normalized.contains('bike') ||
      normalized.contains('car') ||
      normalized.contains('vehicle') ||
      normalized.contains('scooter')) {
    return Icons.directions_car_outlined;
  }
  if (normalized.contains('book') ||
      normalized.contains('read') ||
      normalized.contains('manga')) {
    return Icons.menu_book_outlined;
  }
  if (normalized.contains('home') ||
      normalized.contains('kitchen') ||
      normalized.contains('appliance')) {
    return Icons.home_outlined;
  }
  if (normalized.contains('sport') ||
      normalized.contains('fitness') ||
      normalized.contains('ball')) {
    return Icons.sports_basketball_outlined;
  }
  if (normalized.contains('kid') ||
      normalized.contains('baby') ||
      normalized.contains('toy')) {
    return Icons.child_care_outlined;
  }
  if (normalized.contains('fashion') ||
      normalized.contains('cloth') ||
      normalized.contains('wear') ||
      normalized.contains('shoe')) {
    return Icons.checkroom_outlined;
  }
  if (normalized.contains('tool') ||
      normalized.contains('diy') ||
      normalized.contains('hardware')) {
    return Icons.build_outlined;
  }
  if (normalized == 'all' || normalized == 'all nz') {
    return Icons.explore_outlined;
  }
  return Icons.category_outlined;
}

class _HomeHeader extends StatelessWidget {
  final String location;
  final bool nearYou;
  final VoidCallback onChooseLocation;
  final VoidCallback onScanQr;

  const _HomeHeader({
    required this.location,
    required this.nearYou,
    required this.onChooseLocation,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const KiwiShareLogo(size: 48),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'KiwiShare',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.textBrand,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.6,
                ),
              ),
              Text(
                'Share & Reuse in NZ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.brandSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('home-scan-qr-button'),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
          tooltip: 'Scan QR Code',
          onPressed: onScanQr,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          key: const Key('home-location-button'),
          onPressed: onChooseLocation,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            backgroundColor: AppColors.surfaceMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          icon: Icon(
            nearYou ? Icons.my_location : Icons.location_on_outlined,
            size: 18,
            color: nearYou ? AppColors.brandPrimary : AppColors.textSecondary,
          ),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
              child: nearYou
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Near you'),
                        if (location.isNotEmpty &&
                            location !=
                                HomeDiscoveryProvider.allLocationsLabel) ...[
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '($location)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HomeCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final iconData = _getCategoryIcon(label);
    return ChoiceChip(
      avatar: Icon(
        iconData,
        size: 16,
        color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colors.primaryContainer,
      backgroundColor: isDark
          ? colors.surfaceContainerHighest.withValues(alpha: 0.72)
          : colors.surface,
      side: BorderSide(
        color: selected ? colors.primary : colors.outline,
        width: selected ? 1.5 : 1.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      showCheckmark: false,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? colors.onPrimaryContainer : colors.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _HomeJumboCarousel extends StatelessWidget {
  final List<ItemModel> items;
  final ValueChanged<ItemModel> onOpen;

  const _HomeJumboCarousel({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.brandAccent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Featured Highlights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length > 5 ? 5 : items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return _HomeJumboCard(item: item, onTap: () => onOpen(item));
            },
          ),
        ),
      ],
    );
  }
}

class _HomeJumboCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const _HomeJumboCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.brandPrimaryAlt,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.brandPrimaryAlt,
                        child: const Icon(
                          Icons.local_florist_rounded,
                          color: Colors.white70,
                          size: 40,
                        ),
                      ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandAccent,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'HOT PICK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.isSustainable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco,
                                size: 14,
                                color: AppColors.brandPrimary,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'ECO',
                                style: TextStyle(
                                  color: AppColors.brandPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (item.seller?.isStudentVerified == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1E3A8A,
                            ).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 14,
                                color: Color(0xFF93C5FD),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'STUDENT VERIFIED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              item.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                              border: Border.all(color: Colors.white30),
                            ),
                            child: Text(
                              '\$${item.priceNzd} NZD',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
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
          ),
        ),
      ),
    );
  }
}

class _HomeRecommendedSection extends StatelessWidget {
  final List<ItemModel> items;
  final ValueChanged<ItemModel> onOpen;

  const _HomeRecommendedSection({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final cardHeight = 205.0 + (textScale - 1.0) * 45.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.recommend,
                  color: AppColors.brandPrimary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Recommended for You',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.secondaryContainer
                    : AppColors.brandSecondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                'Top 10',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? colors.onSecondaryContainer
                      : AppColors.brandPrimaryAlt,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Curated based on popularity, freshness & sustainability',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length > 10 ? 10 : items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return _RecommendedProductCard(
                item: item,
                rank: index + 1,
                onTap: () => onOpen(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendedProductCard extends StatelessWidget {
  final ItemModel item;
  final int rank;
  final VoidCallback onTap;

  const _RecommendedProductCard({
    required this.item,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final cardWidth = 155.0 + (textScale - 1.0) * 35.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainerLow : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: colors.outline.withValues(alpha: isDark ? 0.35 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 95,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: AppColors.surfaceMuted,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: AppColors.brandSecondary,
                                    ),
                                  ),
                            )
                          : Container(
                              color: AppColors.surfaceMuted,
                              child: const Icon(
                                Icons.eco_outlined,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$rank',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (item.isSustainable)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: AppColors.brandPrimaryContainer,
                            child: Icon(
                              Icons.eco,
                              size: 13,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      if (item.seller?.isStudentVerified == true)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1E3A8A,
                              ).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 10,
                                  color: Color(0xFF93C5FD),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Student',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$${item.priceNzd}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if (item.seller?.isStudentVerified == true)
                              const Tooltip(
                                message: 'Student Verified Item',
                                child: Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryOptionsError extends StatelessWidget {
  final VoidCallback onRetry;

  const _DiscoveryOptionsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('Categories and locations could not be loaded.'),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _HomeDiscoveryResults extends StatelessWidget {
  final List<ItemModel> products;
  final ItemModel? selectedItem;
  final HomeDiscoveryProvider filters;
  final VoidCallback onShowFilters;
  final ValueChanged<ItemModel> onOpenProduct;
  final VoidCallback? onLocateMe;

  const _HomeDiscoveryResults({
    required this.products,
    required this.selectedItem,
    required this.filters,
    required this.onShowFilters,
    required this.onOpenProduct,
    this.onLocateMe,
  });

  String get _heading {
    if (filters.selectedCategory != 'All') {
      return filters.selectedCategory;
    }
    if (filters.selectedLocation != 'All NZ') {
      return 'Products in ${filters.selectedLocation}';
    }
    return 'Products across NZ';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_heading, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${products.length} items',
              key: const Key('home-results-count'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            OutlinedButton.icon(
              onPressed: onShowFilters,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                filters.activeFilterCount == 0
                    ? 'Sort & filter'
                    : 'Sort & filter (${filters.activeFilterCount})',
              ),
            ),
            _HomeViewToggle(filters: filters),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (filters.view == HomeProductView.map)
          SizedBox(
            height: 400,
            child: HomeProductMap(
              products: products,
              selectedItem: selectedItem,
              userLatitude: filters.userLatitude,
              userLongitude: filters.userLongitude,
              onSelectProduct: (item) => filters.selectPreview(item.id),
              onClearSelection: () => filters.selectPreview(null),
              onOpenProduct: onOpenProduct,
              onLocateMe: onLocateMe,
            ),
          )
        else if (products.isEmpty)
          const _HomeEmptyState()
        else
          _HomeProductsGrid(products: products, onOpen: onOpenProduct),
      ],
    );
  }
}

class _HomeViewToggle extends StatelessWidget {
  final HomeDiscoveryProvider filters;

  const _HomeViewToggle({required this.filters});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HomeViewButton(
            key: const Key('home-grid-view-toggle'),
            tooltip: 'Show product grid',
            icon: Icons.grid_view_outlined,
            selected: filters.view == HomeProductView.grid,
            onPressed: () => filters.setView(HomeProductView.grid),
          ),
          _HomeViewButton(
            key: const Key('home-map-view-toggle'),
            tooltip: 'Show product map',
            icon: Icons.map_outlined,
            selected: filters.view == HomeProductView.map,
            onPressed: () => filters.setView(HomeProductView.map),
          ),
        ],
      ),
    );
  }
}

class _HomeViewButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _HomeViewButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: selected
            ? AppColors.brandPrimaryContainer
            : Colors.transparent,
        foregroundColor: AppColors.brandPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

class _HomeProductsGrid extends StatelessWidget {
  final List<ItemModel> products;
  final ValueChanged<ItemModel> onOpen;

  const _HomeProductsGrid({required this.products, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.58 - (textScale - 1) * 0.20,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        return ItemCard(item: item, onTap: () => onOpen(item));
      },
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Products across NZ',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.60,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => const ItemCardSkeleton(),
        ),
      ],
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _HomeErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: AppSpacing.sm),
          const Text('Could not load products.'),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 48,
              color: AppColors.brandSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No products match these filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try another category, price range, name, or location.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SustainabilityBanner extends StatelessWidget {
  const _SustainabilityBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          Icon(Icons.eco_outlined, color: colors.onPrimaryContainer, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Give items a new life.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Buy local. Reduce waste. Build community.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NzCascadingLocationSheet extends StatefulWidget {
  final HomeDiscoveryProvider filters;
  final VoidCallback onUseCurrentLocation;

  const _NzCascadingLocationSheet({
    required this.filters,
    required this.onUseCurrentLocation,
  });

  @override
  State<_NzCascadingLocationSheet> createState() =>
      _NzCascadingLocationSheetState();
}

class _NzCascadingLocationSheetState extends State<_NzCascadingLocationSheet> {
  late String _selectedRegion;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final current = widget.filters.selectedLocation;
    final parentRegion = NzLocations.findRegionForSuburb(current);
    _selectedRegion = parentRegion ?? 'Auckland';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectLocation(String location) {
    final coords = NzLocations.getApproximateCoordinates(location);
    widget.filters
      ..setLocation(
        location,
        latitude: coords?.latitude,
        longitude: coords?.longitude,
      )
      ..setView(HomeProductView.map);
    Navigator.pop(context);
  }

  int? _getItemCount(String locationName) {
    for (final opt in widget.filters.locations) {
      if (opt.value.toLowerCase() == locationName.toLowerCase()) {
        return opt.count;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeSuburbs = NzLocations.getSuburbsForRegion(_selectedRegion);
    final isSearching = _searchQuery.trim().isNotEmpty;
    final searchResults =
        isSearching ? NzLocations.searchLocations(_searchQuery) : const [];

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.large),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: colors.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Location',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Explore listings across New Zealand regions',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText:
                        'Search region or suburb (e.g. CBD, Newmarket, Dunedin)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? colors.surfaceContainerHighest.withValues(alpha: 0.3)
                        : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        key: const Key('home-near-you-option'),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onUseCurrentLocation();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0C2B1D)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.my_location_rounded,
                                size: 16,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Current Location',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFF6EE7B7)
                                        : const Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        key: const Key('home-location-All NZ'),
                        onTap: () => _selectLocation(
                          HomeDiscoveryProvider.allLocationsLabel,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceContainerHighest.withValues(
                                    alpha: 0.4,
                                  )
                                : colors.surfaceContainerHighest.withValues(
                                    alpha: 0.6,
                                  ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: widget.filters.selectedLocation ==
                                          HomeDiscoveryProvider
                                              .allLocationsLabel &&
                                      !widget.filters.isNearYou
                                  ? AppColors.brandPrimary
                                  : colors.outline.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.public_rounded,
                                size: 16,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'All New Zealand',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: isSearching
                ? searchResults.isEmpty
                    ? Center(
                        child: Text(
                          'No locations match "$_searchQuery"',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: searchResults.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final res = searchResults[i];
                          final target = res['suburb']!.isNotEmpty
                              ? res['suburb']!
                              : res['region']!;
                          final isSelected = widget.filters.selectedLocation
                                      .toLowerCase() ==
                                  target.toLowerCase() &&
                              !widget.filters.isNearYou;
                          final count = _getItemCount(target);
                          return ListTile(
                            key: Key('home-location-$target'),
                            dense: true,
                            leading: Icon(
                              res['type'] == 'Region'
                                  ? Icons.map_outlined
                                  : Icons.location_on_outlined,
                              size: 18,
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : colors.onSurfaceVariant,
                            ),
                            title: Text(res['display']!),
                            subtitle: Text(
                              count != null
                                  ? '${res['type']!} • $count ${count == 1 ? 'item' : 'items'}'
                                  : res['type']!,
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.brandPrimary,
                                    size: 18,
                                  )
                                : null,
                            onTap: () => _selectLocation(target),
                          );
                        },
                      )
                : Row(
                    children: [
                      SizedBox(
                        width: 135,
                        child: Container(
                          color: isDark
                              ? colors.surfaceContainerHighest.withValues(
                                  alpha: 0.2,
                                )
                              : colors.surfaceContainerHighest.withValues(
                                  alpha: 0.3,
                                ),
                          child: ListView.builder(
                            itemCount: NzLocations.regions.length,
                            itemBuilder: (ctx, i) {
                              final reg = NzLocations.regions[i];
                              final isCurrent = reg.name == _selectedRegion;
                              return InkWell(
                                onTap: () => setState(
                                  () => _selectedRegion = reg.name,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? (isDark
                                            ? colors.surface
                                            : Colors.white)
                                        : Colors.transparent,
                                    border: Border(
                                      left: BorderSide(
                                        color: isCurrent
                                            ? AppColors.brandPrimary
                                            : Colors.transparent,
                                        width: 3.5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    reg.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isCurrent
                                          ? AppColors.brandPrimary
                                          : colors.onSurface.withValues(
                                              alpha: 0.85,
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            ListTile(
                              key: Key('home-location-$_selectedRegion'),
                              dense: true,
                              leading: const Icon(
                                Icons.travel_explore_rounded,
                                size: 18,
                                color: AppColors.brandPrimary,
                              ),
                              title: Text(
                                'All $_selectedRegion',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              trailing: widget.filters.selectedLocation
                                              .toLowerCase() ==
                                          _selectedRegion.toLowerCase() &&
                                      !widget.filters.isNearYou
                                  ? const Icon(
                                      Icons.check,
                                      color: AppColors.brandPrimary,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () => _selectLocation(_selectedRegion),
                            ),
                            const Divider(height: 1),
                            for (final suburb in activeSuburbs)
                              Builder(
                                builder: (ctx) {
                                  final count = _getItemCount(suburb);
                                  final isSelected = widget
                                              .filters.selectedLocation
                                              .toLowerCase() ==
                                          suburb.toLowerCase() &&
                                      !widget.filters.isNearYou;
                                  return ListTile(
                                    key: Key('home-location-$suburb'),
                                    dense: true,
                                    leading: const Icon(
                                      Icons.place_outlined,
                                      size: 17,
                                    ),
                                    title: Text(suburb),
                                    subtitle: count != null
                                        ? Text(
                                            '$count ${count == 1 ? 'item' : 'items'}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          )
                                        : null,
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: AppColors.brandPrimary,
                                            size: 18,
                                          )
                                        : null,
                                    onTap: () => _selectLocation(suburb),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
  }
}
