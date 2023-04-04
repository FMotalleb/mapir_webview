part of '../widgets/mapir_webview.dart';

class MapDriver extends Stream<MapState> implements Sink<MapEvent> {
  MapBloc? _mapInstance;
  final _stateController = StreamController<MapState>();
  MapDriver();
  set _map(MapBloc value) {
    if (_mapInstance == null) {
      _mapInstance = value;
    } else {
      throw Exception('this map controller is already attached to an instance');
    }
  }

  void _stateChanged(MapState state) => _stateController.sink.add(state);

  void _addError(Object error, StackTrace trace) => _stateController.sink.addError(error, trace);

  @override
  void add(MapEvent data) {
    if (_mapInstance == null) {
      throw Exception('tried to send event before initializing the map bloc');
    } else if (_mapInstance!.isClosed) {
      throw Exception('tried to send event after closing the map bloc');
    }
    _mapInstance!.add(data);
  }

  @override
  void close() {
    _mapInstance!.close();
  }

  @override
  StreamSubscription<MapState> listen(void Function(MapState event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _stateController.stream.listen(
        onData,
        onError: onError,
        cancelOnError: cancelOnError,
        onDone: onDone,
      );
}
