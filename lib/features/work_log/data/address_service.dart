import 'package:geocoding/geocoding.dart';

class AddressService {
  const AddressService();

  Future<String?> getRoughAddress(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      final city =
          _cleanPart(placemark.locality) ??
          _cleanPart(placemark.subAdministrativeArea) ??
          _cleanPart(placemark.administrativeArea) ??
          '';
      final town =
          _cleanPart(placemark.subLocality) ??
          _cleanPart(placemark.thoroughfare) ??
          '';

      final result = '$city$town';
      if (result.isEmpty) {
        return null;
      }

      return '$result付近';
    } catch (_) {
      return null;
    }
  }

  String? _cleanPart(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
