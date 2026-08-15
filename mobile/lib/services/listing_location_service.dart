import 'package:geolocator/geolocator.dart';

class ListingCoordinates {
  final double latitude;
  final double longitude;

  const ListingCoordinates(this.latitude, this.longitude);
}

class ListingLocationException implements Exception {
  final String message;
  const ListingLocationException(this.message);

  @override
  String toString() => message;
}

abstract class ListingLocationService {
  Future<ListingCoordinates> getApproximatePosition();
}

class DeviceListingLocationService implements ListingLocationService {
  @override
  Future<ListingCoordinates> getApproximatePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ListingLocationException(
        'Location services are off. Choose a city to keep browsing.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ListingLocationException(
        'Location permission was not granted. Choose a city instead.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
    return ListingCoordinates(position.latitude, position.longitude);
  }
}
