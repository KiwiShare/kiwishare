import 'package:flutter/material.dart';

class LocationResult {
  const LocationResult({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _customController = TextEditingController();

  static const List<LocationResult> _recommendedLocations = [
    LocationResult(
      name: 'UoA Student Hub (Alfred Nathan House)',
      latitude: -36.8519,
      longitude: 174.7686,
    ),
    LocationResult(
      name: 'UoA General Library (5 Alfred St)',
      latitude: -36.8513,
      longitude: 174.7679,
    ),
    LocationResult(
      name: 'UoA Engineering Block (20 Symonds St)',
      latitude: -36.8542,
      longitude: 174.7699,
    ),
    LocationResult(
      name: 'UoA Grafton Campus (Park Rd)',
      latitude: -36.8611,
      longitude: 174.7702,
    ),
    LocationResult(
      name: 'Britomart Transport Centre',
      latitude: -36.8443,
      longitude: 174.7684,
    ),
    LocationResult(
      name: 'Newmarket Westfield (Broadway)',
      latitude: -36.8687,
      longitude: 174.7774,
    ),
    LocationResult(
      name: 'Auckland Art Gallery Quad',
      latitude: -36.8510,
      longitude: 174.7663,
    ),
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      LocationResult(name: text, latitude: -36.8523, longitude: 174.7691),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: colors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Share Meetup Location',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customController,
              decoration: InputDecoration(
                hintText: 'Enter custom address or spot...',
                prefixIcon: const Icon(Icons.edit_location_alt_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _submitCustom,
                ),
                filled: true,
                fillColor: colors.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _submitCustom(),
            ),
            const SizedBox(height: 14),
            Text(
              'Recommended Safe Campus & Transit Hubs',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _recommendedLocations.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final loc = _recommendedLocations[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      loc.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, loc),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
