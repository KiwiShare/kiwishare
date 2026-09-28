import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/item_model.dart';
import '../../../services/map_launcher_service.dart';
import '../../../theme/app_theme.dart';

Future<void> showProductLocationMap(
  BuildContext context,
  ItemModel item,
) async {
  final latitude = item.effectiveLatitude;
  final longitude = item.effectiveLongitude;
  if (latitude == null || longitude == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This listing does not have a map location yet.'),
      ),
    );
    return;
  }

  final position = LatLng(latitude, longitude);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listing location',
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.displayLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      MapLauncherService.instance.showNavigationSheet(
                        context: sheetContext,
                        locationName: item.displayLocation,
                        latitude: latitude,
                        longitude: longitude,
                      );
                    },
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const Text('Directions'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  child: GoogleMap(
                    key: const Key('product-location-map'),
                    initialCameraPosition: CameraPosition(
                      target: position,
                      zoom: 14.5,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId(item.id),
                        position: position,
                        infoWindow: InfoWindow(
                          title: item.title,
                          snippet: item.displayLocation,
                        ),
                      ),
                    },
                    mapType: MapType.normal,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Location is approximate and is shown for marketplace discovery.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
