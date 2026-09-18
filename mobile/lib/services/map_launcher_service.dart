import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class MapLauncherService {
  const MapLauncherService();

  static const MapLauncherService instance = MapLauncherService();

  /// Launches Apple Maps with navigation directions
  Future<bool> launchAppleMaps({
    required double? latitude,
    required double? longitude,
    required String locationName,
  }) async {
    Uri uri;
    if (latitude != null && longitude != null) {
      uri = Uri.parse(
        'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d',
      );
    } else {
      uri = Uri.parse(
        'https://maps.apple.com/?daddr=${Uri.encodeComponent(locationName)}&dirflg=d',
      );
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Launches Google Maps with navigation directions
  Future<bool> launchGoogleMaps({
    required double? latitude,
    required double? longitude,
    required String locationName,
  }) async {
    final String dest = (latitude != null && longitude != null)
        ? '$latitude,$longitude'
        : Uri.encodeComponent(locationName);

    // Try app schemes first, then universal web URL
    final List<Uri> candidates = [
      if (Platform.isIOS)
        Uri.parse('comgooglemaps://?daddr=$dest&directionsmode=driving'),
      if (Platform.isAndroid) Uri.parse('google.navigation:q=$dest&mode=d'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving',
      ),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (_) {}
    }

    // Final fallback to web
    try {
      final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$dest',
      );
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Shows native map selection popup (CupertinoActionSheet on iOS, BottomSheet on Android)
  Future<void> showNavigationSheet({
    required BuildContext context,
    required String locationName,
    double? latitude,
    double? longitude,
  }) async {
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(
            locationName.isNotEmpty ? locationName : 'Meetup Location',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          message: const Text('Choose a map application for route navigation'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                launchAppleMaps(
                  latitude: latitude,
                  longitude: longitude,
                  locationName: locationName,
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.compass, size: 20),
                  SizedBox(width: 8),
                  Text('Apple Maps'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                launchGoogleMaps(
                  latitude: latitude,
                  longitude: longitude,
                  locationName: locationName,
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.map, size: 20),
                  SizedBox(width: 8),
                  Text('Google Maps'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(ClipboardData(text: locationName));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Address copied to clipboard!'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.doc_on_clipboard, size: 20),
                  SizedBox(width: 8),
                  Text('Copy Address'),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                locationName.isNotEmpty ? locationName : 'Meetup Location',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose navigation app',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Icon(
                    Icons.navigation_rounded,
                    color: Color(0xFF1A73E8),
                  ),
                ),
                title: const Text(
                  'Google Maps',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Navigate with Google Maps'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  launchGoogleMaps(
                    latitude: latitude,
                    longitude: longitude,
                    locationName: locationName,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.map_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text(
                  'Apple Maps',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Navigate with Apple Maps'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  launchAppleMaps(
                    latitude: latitude,
                    longitude: longitude,
                    locationName: locationName,
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3F4F6),
                  child: Icon(
                    Icons.copy_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
                title: const Text(
                  'Copy Address',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Clipboard.setData(ClipboardData(text: locationName));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address copied to clipboard!'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
  }
}
