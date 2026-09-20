import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class ListingLocation {
  const ListingLocation({required this.label, this.latitude, this.longitude});

  final String label;
  final double? latitude;
  final double? longitude;
}

/// Formats a deliberately approximate coordinate label for cases where reverse
/// geocoding cannot provide a suburb or city name.
String approximateListingLocationLabel(double latitude, double longitude) {
  return 'Approx. ${latitude.toStringAsFixed(2)}, '
      '${longitude.toStringAsFixed(2)}';
}

enum ListingLocationErrorCode {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timedOut,
  unavailable,
}

class ListingLocationException implements Exception {
  const ListingLocationException(this.code);

  final ListingLocationErrorCode code;
}

abstract class ListingLocationService {
  Future<ListingLocation> getCurrentLocation();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class DeviceListingLocationService implements ListingLocationService {
  DeviceListingLocationService({Geocoding? geocoding})
    : _geocoding = geocoding ?? Geocoding();

  final Geocoding _geocoding;

  @override
  Future<ListingLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ListingLocationException(
        ListingLocationErrorCode.servicesDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const ListingLocationException(
        ListingLocationErrorCode.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ListingLocationException(
        ListingLocationErrorCode.permissionDeniedForever,
      );
    }

    try {
      // 1. Check cached/last known position first (instant, <10ms)
      Position? position = await Geolocator.getLastKnownPosition();

      // 2. If no cached position, get current position with low accuracy (fast cell/wifi fix, no satellite wait)
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 8),
      );

      final label = await _locationLabel(position);
      return ListingLocation(
        label: label,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      // 1. Check if last known position became available after timeout
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final label = await _locationLabel(lastKnown);
        return ListingLocation(
          label: label,
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
        );
      }
      // 2. In debug / simulator environment, fallback to Auckland CBD default rather than blocking user
      if (kDebugMode) {
        return const ListingLocation(
          label: 'Auckland CBD, Auckland',
          latitude: -36.8485,
          longitude: 174.7633,
        );
      }
      throw const ListingLocationException(ListingLocationErrorCode.timedOut);
    } on ListingLocationException {
      rethrow;
    } catch (_) {
      throw const ListingLocationException(
        ListingLocationErrorCode.unavailable,
      );
    }
  }

  Future<String> _locationLabel(Position position) async {
    try {
      final placemarks = await _geocoding
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(milliseconds: 2000));
      if (placemarks.isNotEmpty) {
        final label = _areaLabel(placemarks.first);
        if (label.isNotEmpty) {
          return label;
        }
      }
    } catch (_) {
      // Coordinates remain useful when the platform geocoder is unavailable.
    }

    return approximateListingLocationLabel(
      position.latitude,
      position.longitude,
    );
  }

  String _areaLabel(Placemark placemark) {
    final candidates = <String?>[
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea,
      placemark.country,
    ];
    final areas = <String>[];
    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }
      final isDuplicate = areas.any(
        (area) => area.toLowerCase() == value.toLowerCase(),
      );
      if (!isDuplicate) {
        areas.add(value);
      }
      if (areas.length == 2) {
        break;
      }
    }
    return areas.join(', ');
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
