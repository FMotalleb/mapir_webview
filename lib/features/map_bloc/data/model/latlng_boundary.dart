import 'package:latlong2/latlong.dart';

class LatLngBoundary {
  final LatLng northEast;
  final LatLng southWest;
  final LatLng center;
  LatLngBoundary({
    required this.northEast,
    required this.southWest,
  })  : assert(
          northEast.latitude > southWest.latitude && northEast.longitude > southWest.longitude,
          'north east point cannot be lower left than south west point',
        ),
        center = LatLng(
          (northEast.latitude - southWest.latitude) / 2 + southWest.latitude,
          (northEast.longitude - southWest.longitude) / 2 + southWest.longitude,
        );
}
