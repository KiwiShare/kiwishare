import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/item_model.dart';
import '../../../services/map_launcher_service.dart';
import '../../../theme/app_theme.dart';
import 'product_location_map_sheet.dart';

class ProductLocationSection extends StatelessWidget {
  const ProductLocationSection({super.key, required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final latitude = item.effectiveLatitude;
    final longitude = item.effectiveLongitude;
    final hasMap = latitude != null && longitude != null;

    return Column(
      key: const Key('detail-location-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.place_rounded,
                color: Color(0xFF0284C7),
                size: 21,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup location',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.displayLocation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (hasMap)
              IconButton.filledTonal(
                key: const Key('detail-location-directions-button'),
                tooltip: 'Directions',
                onPressed: () {
                  MapLauncherService.instance.showNavigationSheet(
                    context: context,
                    locationName: item.displayLocation,
                    latitude: latitude,
                    longitude: longitude,
                  );
                },
                icon: const Icon(Icons.directions_rounded, size: 20),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (hasMap)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.large),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('detail-location-map-button'),
              onTap: () => showProductLocationMap(context, item),
              child: SizedBox(
                height: 210,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: GoogleMap(
                        key: const Key('detail-location-inline-map'),
                        initialCameraPosition: CameraPosition(
                          target: LatLng(latitude, longitude),
                          zoom: 14.4,
                        ),
                        markers: {
                          Marker(
                            markerId: MarkerId(item.id),
                            position: LatLng(latitude, longitude),
                          ),
                        },
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        liteModeEnabled: true,
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.12),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_full_rounded,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Open map',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.map_outlined, color: colors.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'The seller has shared an area, but no map coordinates are available for this listing.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The map is approximate. Confirm the exact meetup point with the seller before travelling.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
