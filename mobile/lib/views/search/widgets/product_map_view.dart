import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/item_model.dart';
import '../../../theme/app_theme.dart';

class ProductMapView extends StatefulWidget {
  final List<ItemModel> products;
  final String? selectedItemId;
  final double? userLatitude;
  final double? userLongitude;
  final ValueChanged<ItemModel> onSelectProduct;
  final VoidCallback onClearSelection;

  const ProductMapView({
    super.key,
    required this.products,
    required this.selectedItemId,
    required this.userLatitude,
    required this.userLongitude,
    required this.onSelectProduct,
    required this.onClearSelection,
  });

  @override
  State<ProductMapView> createState() => _ProductMapViewState();
}

class _ProductMapViewState extends State<ProductMapView> {
  final MapController _mapController = MapController();
  int? _visibleCount;

  List<ItemModel> get _mappedProducts =>
      widget.products.where((item) => item.hasMapLocation).toList();

  LatLng get _initialCenter {
    if (widget.userLatitude != null && widget.userLongitude != null) {
      return LatLng(widget.userLatitude!, widget.userLongitude!);
    }
    if (_mappedProducts.isNotEmpty) {
      final item = _mappedProducts.first;
      return LatLng(item.latitude!, item.longitude!);
    }
    return const LatLng(-41.0, 174.0);
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
    _mapController.move(camera.center, (camera.zoom + delta).clamp(4, 18));
  }

  @override
  Widget build(BuildContext context) {
    if (_mappedProducts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'These products do not have approximate map locations yet.',
          ),
        ),
      );
    }

    return Semantics(
      label: 'Map showing product approximate locations',
      child: Stack(
        children: [
          FlutterMap(
            key: const Key('products-map'),
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: widget.userLatitude == null ? 5.4 : 12,
              minZoom: 4,
              maxZoom: 18,
              onTap: (_, _) => widget.onClearSelection(),
              onMapReady: () => _updateVisibleCount(_mapController.camera),
              onPositionChanged: (camera, _) => _updateVisibleCount(camera),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.kiwishare',
              ),
              MarkerLayer(
                markers: [
                  for (final product in _mappedProducts)
                    Marker(
                      point: LatLng(product.latitude!, product.longitude!),
                      width: 56,
                      height: 56,
                      child: Semantics(
                        button: true,
                        label: '${product.title}, ${product.location}',
                        child: IconButton.filled(
                          key: Key('product-marker-${product.id}'),
                          tooltip: product.title,
                          onPressed: () => widget.onSelectProduct(product),
                          style: IconButton.styleFrom(
                            backgroundColor: widget.selectedItemId == product.id
                                ? AppColors.brandAccent
                                : AppColors.brandPrimary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.inventory_2_outlined),
                        ),
                      ),
                    ),
                  if (widget.userLatitude != null &&
                      widget.userLongitude != null)
                    Marker(
                      point: LatLng(
                        widget.userLatitude!,
                        widget.userLongitude!,
                      ),
                      width: 32,
                      height: 32,
                      child: const Tooltip(
                        message: 'Your approximate location',
                        child: Icon(Icons.my_location, color: AppColors.info),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            left: AppSpacing.md,
            top: AppSpacing.md,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: const [
                  BoxShadow(blurRadius: 8, color: Colors.black26),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  '${_visibleCount ?? _mappedProducts.length} items in this area',
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.md,
            top: AppSpacing.md,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'products-map-zoom-in',
                  tooltip: 'Zoom in',
                  onPressed: () => _changeZoom(1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: AppSpacing.sm),
                FloatingActionButton.small(
                  heroTag: 'products-map-zoom-out',
                  tooltip: 'Zoom out',
                  onPressed: () => _changeZoom(-1),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
