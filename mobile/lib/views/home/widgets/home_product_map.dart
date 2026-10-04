import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/item_model.dart';
import '../../../theme/app_theme.dart';
import 'home_product_preview_card.dart';

class HomeProductMap extends StatefulWidget {
  // Keep enough zoom-out headroom to make the NZ-wide map genuinely
  // explorable. The previous 4.8 minimum was only 0.2 below the default
  // zoom of 5, which made zoom-out appear broken on physical devices.
  static const minimumZoom = 3.0;
  static const maximumZoom = 16.0;

  // HomeProductMap is embedded in a SingleChildScrollView. Without an
  // explicit recognizer the parent scroll view can win Flutter's gesture
  // arena before the native Google Map sees the interaction. Eagerly claiming
  // gestures that begin on the map keeps pan/pinch/rotate reliable on both
  // Android and iOS.
  static final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers =
      <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      };
  static const newZealandCenter = LatLng(-41.2, 172.7);
  static final newZealandCameraBounds = LatLngBounds(
    southwest: const LatLng(-49.5, 164.0),
    northeast: const LatLng(-32.0, 180.0),
  );

  final List<ItemModel> products;
  final ItemModel? selectedItem;
  final double? userLatitude;
  final double? userLongitude;
  final ValueChanged<ItemModel> onSelectProduct;
  final VoidCallback onClearSelection;
  final ValueChanged<ItemModel> onOpenProduct;
  final VoidCallback? onLocateMe;

  const HomeProductMap({
    super.key,
    required this.products,
    required this.selectedItem,
    required this.userLatitude,
    required this.userLongitude,
    required this.onSelectProduct,
    required this.onClearSelection,
    required this.onOpenProduct,
    this.onLocateMe,
  });

  @override
  State<HomeProductMap> createState() => _HomeProductMapState();
}

class _HomeProductMapState extends State<HomeProductMap> {
  GoogleMapController? _controller;
  int? _visibleCount;

  List<ItemModel> get _mappedProducts =>
      widget.products.where((item) => item.hasMapLocation).toList();

  bool get _hasSelectedLocation =>
      widget.userLatitude != null && widget.userLongitude != null;

  LatLng get _selectedLocation => LatLng(
    widget.userLatitude ?? HomeProductMap.newZealandCenter.latitude,
    widget.userLongitude ?? HomeProductMap.newZealandCenter.longitude,
  );

  @override
  void didUpdateWidget(covariant HomeProductMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasSelectedLocation &&
        (oldWidget.userLatitude != widget.userLatitude ||
            oldWidget.userLongitude != widget.userLongitude)) {
      unawaited(
        _controller?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _selectedLocation, zoom: 10),
          ),
        ),
      );
    }
  }

  Future<void> _updateVisibleCount() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final bounds = await controller.getVisibleRegion();
      final count = _mappedProducts.where((item) {
        final point = LatLng(item.effectiveLatitude!, item.effectiveLongitude!);
        final west = bounds.southwest.longitude;
        final east = bounds.northeast.longitude;
        final lonInside = west <= east
            ? point.longitude >= west && point.longitude <= east
            : point.longitude >= west || point.longitude <= east;
        return point.latitude >= bounds.southwest.latitude &&
            point.latitude <= bounds.northeast.latitude &&
            lonInside;
      }).length;
      if (mounted && count != _visibleCount) {
        setState(() => _visibleCount = count);
      }
    } catch (_) {
      // The controller can briefly be unavailable while the platform view
      // is being recreated. Keep the previous count in that case.
    }
  }

  Future<void> _recenter() async {
    final controller = _controller;
    if (_hasSelectedLocation && controller != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedLocation, zoom: 11),
        ),
      );
      return;
    }
    widget.onLocateMe?.call();
  }

  Set<Marker> _markers() {
    final markers = <Marker>{
      for (final item in _mappedProducts)
        Marker(
          markerId: MarkerId('product-${item.id}'),
          position: LatLng(item.effectiveLatitude!, item.effectiveLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            widget.selectedItem?.id == item.id
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: item.title,
            snippet: '\$${item.priceNzd} · ${item.displayLocation}',
            onTap: () => widget.onOpenProduct(item),
          ),
          onTap: () => widget.onSelectProduct(item),
        ),
    };

    if (_hasSelectedLocation) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected-area'),
          position: _selectedLocation,
          zIndexInt: -1,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Selected area'),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initialTarget = _hasSelectedLocation
        ? _selectedLocation
        : HomeProductMap.newZealandCenter;

    return Semantics(
      label: 'Google Map showing approximate product locations in New Zealand',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: Stack(
            children: [
              GoogleMap(
                key: const Key('home-products-map'),
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: _hasSelectedLocation ? 10 : 5,
                ),
                mapType: MapType.normal,
                markers: _markers(),
                minMaxZoomPreference: const MinMaxZoomPreference(
                  HomeProductMap.minimumZoom,
                  HomeProductMap.maximumZoom,
                ),
                cameraTargetBounds: CameraTargetBounds(
                  HomeProductMap.newZealandCameraBounds,
                ),
                gestureRecognizers: HomeProductMap.gestureRecognizers,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                compassEnabled: false,
                mapToolbarEnabled: false,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                // Native zoom controls are Android-only. Keep them disabled so
                // Android and iOS share the same gesture-first interaction.
                zoomControlsEnabled: false,
                buildingsEnabled: true,
                onMapCreated: (controller) {
                  _controller = controller;
                  unawaited(_updateVisibleCount());
                },
                onCameraIdle: _updateVisibleCount,
                onTap: (_) => widget.onClearSelection(),
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
                child: Material(
                  color: colors.surface.withValues(alpha: 0.96),
                  elevation: 2,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: IconButton(
                    key: const Key('home-map-locate-me'),
                    tooltip: _hasSelectedLocation
                        ? 'Recenter map'
                        : 'Use my location',
                    onPressed: _recenter,
                    icon: Icon(
                      _hasSelectedLocation
                          ? Icons.center_focus_strong_rounded
                          : Icons.my_location_rounded,
                    ),
                    color: colors.primary,
                  ),
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

class _MapStatusPill extends StatelessWidget {
  final String label;

  const _MapStatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
