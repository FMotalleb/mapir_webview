part of 'map_bloc.dart';

abstract class MapState extends Equatable {
  const MapState();
}

class MapBlocInitial extends MapState {
  @override
  List<Object> get props => [];
}

class MapBlocCreatedMapController extends MapState {
  final WebViewController controller;
  const MapBlocCreatedMapController({
    required this.controller,
  });
  @override
  List<Object> get props => [
        controller,
      ];
}

class RawEventState extends MapState {
  final Map<String, dynamic> event;

  const RawEventState({
    required this.event,
  });

  @override
  List<Object?> get props => [event];
}

class MapTapState extends RawEventState {
  final LatLng point;
  const MapTapState({
    required super.event,
    required this.point,
  });
  factory MapTapState.fromMap(Map<String, dynamic> map) {
    final data = map['params'];
    // {
    //   "event": "click",
    //   "params": {"lat": 36.57142382346277, "lng": 53.02551269531251}
    // };
    if (data is! Map<String, dynamic>) {
      throw Exception('given map does not contain Map<String,dynamic>(`params`)');
    }
    final lat = data['lat'];
    final lng = data['lng'];
    if (lat is! num || lng is! num) {
      throw Exception('lat or long values are not in correct format they must be of type num');
    }
    final point = LatLng(lat.toDouble(), lng.toDouble());
    return MapTapState(
      event: map,
      point: point,
    );
  }
  @override
  List<Object?> get props => [super.props, point];
}

class MapDoubleTapState extends RawEventState {
  final LatLng point;
  const MapDoubleTapState({
    required super.event,
    required this.point,
  });
  factory MapDoubleTapState.fromMap(Map<String, dynamic> map) {
    final data = map['params'];
    if (data is! Map<String, dynamic>) {
      throw Exception('given map does not contain Map<String,dynamic>(`params`)');
    }
    final lat = data['lat'];
    final lng = data['lng'];
    if (lat is! num || lng is! num) {
      throw Exception('lat or long values are not in correct format they must be of type num');
    }
    final point = LatLng(lat.toDouble(), lng.toDouble());
    return MapDoubleTapState(
      event: map,
      point: point,
    );
  }
  @override
  List<Object?> get props => [super.props, point];
}

class MapStateChanged extends MapState {
  final LatLngBoundary boundary;
  final double zoomLevel;
  const MapStateChanged(
    this.boundary,
    this.zoomLevel,
  );
  LatLng get center => boundary.center;
  factory MapStateChanged.fromMap(Map<String, dynamic> map) {
    final zoom = map['zoom'];
    final northEastMap = map['bounds']?['north_east'];
    final southWestMap = map['bounds']?['south_west'];
    if (zoom is! num ||
        northEastMap['lat'] is! num ||
        northEastMap['lng'] is! num ||
        southWestMap['lat'] is! num ||
        southWestMap['lng'] is! num) {
      throw Exception('points or zoom carry invalid value');
    }

    final southWest = LatLng(southWestMap['lat'].toDouble(), southWestMap['lng'].toDouble());
    final northEast = LatLng(northEastMap['lat'].toDouble(), northEastMap['lng'].toDouble());
    return MapStateChanged(
      LatLngBoundary(northEast: northEast, southWest: southWest),
      zoom.toDouble(),
    );
  }
  @override
  List<Object?> get props => [
        boundary,
        zoomLevel,
      ];
}
