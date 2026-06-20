import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  // Replace with your office coordinates
  static const double officeLatitude = 30.483667;
  static const double officeLongitude = 77.131694;
  static const double officeRadiusInMeters = 50.0;

  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  static bool isWithinRadius(Position currentPosition) {
    const Distance distance = Distance();
    final double meter = distance.as(
      LengthUnit.Meter,
      LatLng(currentPosition.latitude, currentPosition.longitude),
      LatLng(officeLatitude, officeLongitude),
    );

    return meter <= officeRadiusInMeters;
  }

  static double getDistanceFromOffice(Position currentPosition) {
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      LatLng(currentPosition.latitude, currentPosition.longitude),
      LatLng(officeLatitude, officeLongitude),
    );
  }
}
