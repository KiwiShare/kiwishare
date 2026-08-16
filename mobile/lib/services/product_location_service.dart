import 'dart:math';

import 'package:geolocator/geolocator.dart';

class ProductLocationException implements Exception {
  final String message;

  const ProductLocationException(this.message);

  @override
  String toString() => message;
}

abstract class ProductLocationService {
  Future<ProductLocationContext> getCurrentLocation();
}

class ProductLocationContext {
  final String city;
  final double latitude;
  final double longitude;

  const ProductLocationContext({
    required this.city,
    required this.latitude,
    required this.longitude,
  });
}

class DeviceProductLocationService implements ProductLocationService {
  static const _cityCoordinates = <String, (double, double)>{
    'Auckland': (-36.8485, 174.7633),
    'Wellington': (-41.2866, 174.7756),
    'Hamilton': (-37.7870, 175.2793),
    'Christchurch': (-43.5321, 172.6362),
    'Dunedin': (-45.8788, 170.5028),
  };

  @override
  Future<ProductLocationContext> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ProductLocationException(
        'Location services are off. Choose a city to keep browsing.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ProductLocationException(
        'Location permission was not granted. Choose a city instead.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
    final city = _cityCoordinates.entries.reduce((closest, candidate) {
      final closestDistance = _distanceSquared(
        position.latitude,
        position.longitude,
        closest.value.$1,
        closest.value.$2,
      );
      final candidateDistance = _distanceSquared(
        position.latitude,
        position.longitude,
        candidate.value.$1,
        candidate.value.$2,
      );
      return candidateDistance < closestDistance ? candidate : closest;
    }).key;
    return ProductLocationContext(
      city: city,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

double _distanceSquared(double lat1, double lng1, double lat2, double lng2) {
  final latitudeDifference = lat1 - lat2;
  final longitudeDifference = (lng1 - lng2) * cos(lat1 * pi / 180);
  return latitudeDifference * latitudeDifference +
      longitudeDifference * longitudeDifference;
}
