import 'package:mapir_webview/mapir_webview.dart';

class MapEventDriver implements Sink<MapEvent> {
  MapBloc? _map;
  set map(MapBloc value) {
    if (_map == null) {
      _map = value;
    } else {
      throw Exception('this map controller is already attached to an instance');
    }
  }

  MapEventDriver();

  @override
  void add(MapEvent data) {
    if (_map == null) {
      throw Exception('tried to send event before initializing the map bloc');
    } else if (_map!.isClosed) {
      throw Exception('tried to send event after closing the map bloc');
    }
    _map!.add(data);
  }

  @override
  void close() {
    _map!.close();
  }
}
