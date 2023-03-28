part of 'map_bloc.dart';

abstract class MapEvent extends Equatable {
  const MapEvent();
}

class _InternalEmitter<T extends MapState> extends MapEvent {
  final T state;

  const _InternalEmitter(this.state);

  @override
  List<Object?> get props => [state];
}

class RequestMapControllerEvent extends MapEvent {
  @override
  List<Object> get props => [];
}

class MapTapEvent extends MapEvent {
  final LatLng location;

  const MapTapEvent(this.location);
  @override
  List<Object> get props => [location];
}

abstract class IInjectableJsEvent extends MapEvent {
  bool get shouldRunAfterMapInited => true;

  String get rawJs;
}

class InjectRawJs extends IInjectableJsEvent {
  @override
  final String rawJs;

  InjectRawJs(this.rawJs);
  @override
  List<Object?> get props => [rawJs];
}

class FlyToLatLngEvent extends IInjectableJsEvent {
  final LatLng point;
  final double zoomLevel;

  FlyToLatLngEvent({
    required this.point,
    this.zoomLevel = 13,
  }) : assert(
          zoomLevel > 5 && zoomLevel < 18,
          'cannot set zoom level below `5` or higher than 18',
        );
  @override
  String get rawJs => 'window.map.map.flyTo([${point.latitude}, ${point.longitude}],$zoomLevel);';
  @override
  List<Object> get props => [point, zoomLevel];
}

class CreateMarkerOnMapEvent extends IInjectableJsEvent {
  final String name;
  final Uri iconUrl;
  final LatLng location;
  final Size iconSize;
  final Offset iconAnchor;
  final bool draggable;
  final bool moveToMarker;
  //TODO rotation?
  //TODO popup control
  CreateMarkerOnMapEvent({
    required this.name,
    required this.iconUrl,
    this.moveToMarker = false,
    required this.location,
    this.iconSize = const Size(20, 20),
    Offset? iconAnchor,
    this.draggable = false,
  }) : iconAnchor = iconAnchor ?? Offset(iconSize.width / 2, iconSize.height);

  @override
  String get rawJs => '''
var icon = {
  iconUrl:    '$iconUrl',
  iconSize:   [${iconSize.width}, ${iconSize.height}], 
  iconAnchor: [${iconAnchor.dx}, ${iconAnchor.dy}], 
};

window.map.addMarker({
  name: '$name',
  latlng: {
      lat: ${location.latitude},
      lng: ${location.longitude},
  },

  icon: icon,
  popup: false,
  clickable:false,
  pan: $moveToMarker,
  draggable: $draggable,
  history: true,
});''';
  @override
  List<Object?> get props => [
        name,
        iconUrl,
        location,
        iconSize,
        iconAnchor,
        draggable,
      ];
}

class RemoveMarkerEvent extends IInjectableJsEvent {
  final String name;

  RemoveMarkerEvent(this.name);

  @override
  String get rawJs => '''
window.map.removeMarker({
  name: '$name',
});
''';
  @override
  List<Object?> get props => [name];
}

class ClearMarkersEvent extends IInjectableJsEvent {
  ClearMarkersEvent();

  @override
  String get rawJs => '''
window.map.removeMarkers({
  group: window.map.groups.features.markers,
});
''';
  @override
  List<Object?> get props => [];
}

class ZoomInEvent extends IInjectableJsEvent {
  final int id;
  ZoomInEvent(
    this.id,
  );

  @override
  List<Object?> get props => [id];

  @override
  String get rawJs => 'window.map.map.zoomIn()';
}

class ZoomOutEvent extends IInjectableJsEvent {
  final int id;
  ZoomOutEvent(
    this.id,
  );

  @override
  List<Object?> get props => [id];

  @override
  String get rawJs => 'window.map.map.zoomOut()';
}
