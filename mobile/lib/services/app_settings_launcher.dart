import 'package:geolocator/geolocator.dart';

abstract interface class AppSettingsLauncher {
  Future<bool> openAppSettings();
}

class DeviceAppSettingsLauncher implements AppSettingsLauncher {
  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
