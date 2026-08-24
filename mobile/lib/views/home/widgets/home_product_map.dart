import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/item_model.dart';
import '../../../theme/app_theme.dart';
import 'home_product_preview_card.dart';

class HomeProductMap extends StatefulWidget {
  static final newZealandLandBounds = LatLngBounds(
    const LatLng(-47.6, 166.0),
    const LatLng(-34.0, 179.3),
  );

  static final newZealandCameraBounds = LatLngBounds(
    const LatLng(-49.5, 164.0),
    const LatLng(-32.0, 180.0),
  );

  static const minimumZoom = 4.8;
  static const maximumZoom = 11.0;
  static const tileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

  final List<ItemModel> products;
  final ItemModel? selectedItem;
  final double? userLatitude;
  final double? userLongitude;
  final ValueChanged<ItemModel> onSelectProduct;
  final VoidCallback onClearSelection;
  final ValueChanged<ItemModel> onOpenProduct;

  const HomeProductMap({
    super.key,
    required this.products,
    required this.selectedItem,
    required this.userLatitude,
    required this.userLongitude,
    required this.onSelectProduct,
    required this.onClearSelection,
    required this.onOpenProduct,
  });

  @override
  State<HomeProductMap> createState() => _HomeProductMapState();
}

class _HomeProductMapState extends State<HomeProductMap> {
  final MapController _mapController = MapController();
  int? _visibleCount;

  List<ItemModel> get _mappedProducts =>
      widget.products.where((item) => item.hasMapLocation).toList();

  @override
  void didUpdateWidget(covariant HomeProductMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userLatitude != null &&
        widget.userLongitude != null &&
        (oldWidget.userLatitude != widget.userLatitude ||
            oldWidget.userLongitude != widget.userLongitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(
            LatLng(widget.userLatitude!, widget.userLongitude!),
            9,
          );
        }
      });
    }
  }

  void _updateVisibleCount(MapCamera camera) {
    final count = _mappedProducts.where((item) {
      return camera.visibleBounds.contains(
        LatLng(item.latitude!, item.longitude!),
      );
    }).length;
    if (count != _visibleCount && mounted) {
      setState(() => _visibleCount = count);
    }
  }

  void _changeZoom(double delta) {
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(
      HomeProductMap.minimumZoom,
      HomeProductMap.maximumZoom,
    );
    _mapController.move(camera.center, zoom.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedLocation =
        widget.userLatitude != null && widget.userLongitude != null;
    return Semantics(
      label: 'Map showing approximate product locations in New Zealand',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: Stack(
            children: [
              FlutterMap(
                key: const Key('home-products-map'),
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: hasSelectedLocation
                      ? LatLng(widget.userLatitude!, widget.userLongitude!)
                      : const LatLng(-41.2, 172.7),
                  initialZoom: hasSelectedLocation ? 9 : 5,
                  initialCameraFit: hasSelectedLocation
                      ? null
                      : CameraFit.bounds(
                          bounds: HomeProductMap.newZealandLandBounds,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          minZoom: HomeProductMap.minimumZoom,
                          maxZoom: 5.2,
                        ),
                  minZoom: HomeProductMap.minimumZoom,
                  maxZoom: HomeProductMap.maximumZoom,
                  backgroundColor: AppColors.surfaceMuted,
                  cameraConstraint: CameraConstraint.containCenter(
                    bounds: HomeProductMap.newZealandCameraBounds,
                  ),
                  keepAlive: true,
                  onTap: (_, _) => widget.onClearSelection(),
                  onMapReady: () => _updateVisibleCount(_mapController.camera),
                  onPositionChanged: (camera, _) => _updateVisibleCount(camera),
                ),
                children: [
                  TileLayer(
                    urlTemplate: HomeProductMap.tileUrl,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.kiwishare.app',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final product in _mappedProducts)
                        Marker(
                          point: LatLng(product.latitude!, product.longitude!),
                          width: 76,
                          height: 48,
                          child: Semantics(
                            button: true,
                            selected: widget.selectedItem?.id == product.id,
                            label:
                                '${product.title}, ${product.priceNzd} New Zealand dollars',
                            child: _ProductPriceMarker(
                              key: Key('home-product-marker-${product.id}'),
                              price: product.priceNzd,
                              selected: widget.selectedItem?.id == product.id,
                              onPressed: () => widget.onSelectProduct(product),
                            ),
                          ),
                        ),
                      if (hasSelectedLocation)
                        Marker(
                          point: LatLng(
                            widget.userLatitude!,
                            widget.userLongitude!,
                          ),
                          width: 40,
                          height: 40,
                          child: const Tooltip(
                            message: 'Your approximate location',
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.my_location,
                                color: AppColors.info,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    showFlutterMapAttribution: false,
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                      TextSourceAttribution('CARTO'),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: AppSpacing.md,
                top: AppSpacing.md,
                child: _MapStatusPill(
                  label:
                      '${_visibleCount ?? _mappedProducts.length} items in this area',
                ),
              ),
              Positioned(
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: Column(
                  children: [
                    _MapControlButton(
                      key: const Key('home-map-zoom-in'),
                      tooltip: 'Zoom in',
                      icon: Icons.add,
                      onPressed: () => _changeZoom(1),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MapControlButton(
                      key: const Key('home-map-zoom-out'),
                      tooltip: 'Zoom out',
                      icon: Icons.remove,
                      onPressed: () => _changeZoom(-1),
                    ),
                  ],
                ),
              ),
              if (_mappedProducts.isEmpty)
                const Center(
                  child: _MapStatusPill(
                    label: 'No map-ready products match these filters',
                  ),
                ),
              if (widget.selectedItem != null)
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: HomeProductPreviewCard(
                    item: widget.selectedItem!,
                    onOpen: () => widget.onOpenProduct(widget.selectedItem!),
                    onClose: widget.onClearSelection,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPriceMarker extends StatelessWidget {
  final String price;
  final bool selected;
  final VoidCallback onPressed;

  const _ProductPriceMarker({
    super.key,
    required this.price,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandAccent : AppColors.brandPrimary,
      elevation: selected ? 3 : 1,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '\$$price',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: AppColors.brandPrimary,
        icon: Icon(icon),
      ),
    );
  }
}

class _MapStatusPill extends StatelessWidget {
  final String label;

  const _MapStatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}
