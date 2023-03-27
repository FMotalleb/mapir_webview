import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapir_webview/features/debouncer/debouncer.dart';
import 'package:mapir_webview/features/map_bloc/data/model/latlng_boundary.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
part 'map_event.dart';
part 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final String mapIrToken;
  final LatLng initialPoint;
  final int initialZoom;
  WebViewController? _controller;
  final Logger _logger;
  Logger _createLoggerFor(MapEvent event) {
    return Logger('${_logger.fullName}.${event.runtimeType}');
  }

  Logger _extendLogger(Logger logger, String name) {
    return Logger('${logger.fullName}.$name');
  }

  static MapBloc of(BuildContext context) => context.read<MapBloc>();

  MapBloc({
    required this.mapIrToken,
    required this.initialZoom,
    required this.initialPoint,
    required Uri baseMapUri,
    String loggerName = 'Global.MapBloc',
  })  : _logger = Logger(loggerName),
        super(MapBlocInitial()) {
    on<RequestMapControllerEvent>((event, emit) async {
      final logger = _createLoggerFor(event);
      if (_controller != null) {
        logger.info('found previous controller reusing it');
        return emit(
          MapBlocCreatedMapController(controller: _controller!),
        );
      }
      final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      final WebViewController controller = WebViewController.fromPlatformCreationParams(params);
      _controller = controller;
      logger.info('initializing the controller');
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0x00000000));
      logger.info('creating navigation delegate to prevent any unwanted navigation');
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            final logger = _extendLogger(_logger, 'NavigationDelegate.onWebResourceError');
            logger.shout(
              '''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}''',
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            final logger = _extendLogger(_logger, 'NavigationDelegate.onNavigationRequest');
            logger.warning('preventing navigation to ${request.url}');
            return NavigationDecision.prevent;
          },
        ),
      );
      await _createChannels(controller);

      await controller.loadHtmlString(
        _pageCode,
        baseUrl: baseMapUri.toString(),
      );
      logger.fine('loading html page at `${DateTime.now()}`');
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(true);
        platform.setMediaPlaybackRequiresUserGesture(false);
      }
      emit(
        MapBlocCreatedMapController(
          controller: controller,
        ),
      );
    });
    on<IInjectableJsEvent>(
      (event, emit) async {
        final logger = _createLoggerFor(event);

        if (_controller == null) {
          logger.shout('controller is not initialized yet');
          return;
        }
        final js = '\$(document).ready(  function () {${event.rawJs}});';
        logger.info('injecting the js:\n$js');
        final result = await _controller!.runJavaScriptReturningResult(js);
        logger.info('result: $result');
      },
    );
    on<_InternalEmitter>(
      (event, emit) => emit(event.state),
    );
  }

  Future<void> _createChannels(WebViewController controller) async {
    final mapStateListenerLogger = _extendLogger(
      _logger,
      'Channel.MapStateListener',
    );
    final tapListenerLogger = _extendLogger(
      _logger,
      'Channel.TapListener',
    );
    final publicLogger = _extendLogger(
      _logger,
      'Channel.Public',
    );

    await controller.addJavaScriptChannel(
      'TapListener',
      onMessageReceived: (JavaScriptMessage message) {
        tapListenerLogger.info('Received:\n${message.message}');
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          add(
            _InternalEmitter(
              MapTapState.fromMap(data),
            ),
          );
        } catch (e, st) {
          tapListenerLogger.shout(
            '''
Error in Parsing Message as JSON Object in TapListener: Channel Reservation by Package
The system has encountered an error while attempting to parse the message in TapListener as a JSON object. To prevent further errors, it is advised that you refrain from sending any messages to this channel. This channel has been reserved by the package itself and should not be used for external communication.

If you require a channel for passing messages, we recommend using the PublicListener instead. Please note that when passing messages, it is important to ensure that they conform to the expected format and data type requirements.

In the event that you did not send any message to this channel and are still experiencing issues, we encourage you to open an issue with our support team. Our team will work diligently to resolve the issue and ensure that your system is functioning properly.
''',
            e,
            st,
          );
        }
      },
    );
    await controller.addJavaScriptChannel(
      'MapStateListener',
      onMessageReceived: (JavaScriptMessage message) {
        Debounce.debounce(
          'MapStateListener',
          const Duration(milliseconds: 350),
          () {
            try {
              mapStateListenerLogger.info('Received:\n${message.message}');
              final data = jsonDecode(message.message) as Map<String, dynamic>;
              add(
                _InternalEmitter(
                  MapStateChanged.fromMap(data),
                ),
              );
            } catch (e, st) {
              mapStateListenerLogger.shout(
                '''
Error in Parsing Message as JSON Object in MapStateListener: Channel Reservation by Package
The system has encountered an error while attempting to parse the message in MapStateListener as a JSON object. To prevent further errors, it is advised that you refrain from sending any messages to this channel. This channel has been reserved by the package itself and should not be used for external communication.

If you require a channel for passing messages, we recommend using the PublicListener instead. Please note that when passing messages, it is important to ensure that they conform to the expected format and data type requirements.

In the event that you did not send any message to this channel and are still experiencing issues, we encourage you to open an issue with our support team. Our team will work diligently to resolve the issue and ensure that your system is functioning properly.
''',
                e,
                st,
              );
            }
          },
        );
      },
    );
    await controller.addJavaScriptChannel(
      'PublicListener',
      onMessageReceived: (JavaScriptMessage message) {
        publicLogger.info('Received:\n${message.message}');
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          add(
            _InternalEmitter(
              RawEventState(
                event: data,
              ),
            ),
          );
        } catch (e, st) {
          publicLogger.shout(
            '''
Error in Parsing Message as JSON Object in PublicListener: Invalid Data Type
The system has encountered an error while attempting to parse the message in PublicListener as a JSON object. It is recommended that you pass stringified JSON objects and not arrays or strings, as these data types are not acceptable by the listener.

To prevent further errors, please ensure that the data type being passed conforms to the expected format. Passing invalid data types may result in errors and hinder the proper functioning of the system.''',
            e,
            st,
          );
        }
      },
    );
  }

  String get _pageCode => '''<!DOCTYPE html>
<html>

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="https://cdn.map.ir/web-sdk/1.4.2/css/mapp.min.css">
    <link rel="stylesheet" href="https://cdn.map.ir/web-sdk/1.4.2/css/fa/style.css">
    <style>
        @charset "utf-8";

        html,
        body {
            width: 100%;
            height: 100%;
            padding: 0;
            margin: 0;
        }

        html {
            font-size: 10px;
        }

        body {
            overflow: hidden;
        }

        #app {
            width: 100%;
            height: 100%;
        }
    </style>
</head>

<body>
    <div id="app"></div>
    <script type="text/javascript" src="https://cdn.map.ir/web-sdk/1.4.2/js/jquery-3.2.1.min.js"></script>
    <script type="text/javascript" src="https://cdn.map.ir/web-sdk/1.4.2/js/mapp.env.js"></script>
    <script type="text/javascript" src="https://cdn.map.ir/web-sdk/1.4.2/js/mapp.min.js"></script>
    <script>
      $_initializerScript
    </script>
</body>

</html>
''';

  String get _initializerScript => '''\$(document).ready(
  function () {
      window.map = new Mapp(
          {
              element: '#app',
              presets: {
                  latlng: {
                      lat: ${initialPoint.latitude},
                      lng: ${initialPoint.longitude},
                  }, 
                  zoom: $initialZoom,
              },
              apiKey: '$mapIrToken',
          });
      window.map.addVectorLayers(); 
      window.map.map.on('click', function (e) {
          TapListener.postMessage(
              JSON.stringify(
                  {
                      event: 'click',
                      params: e.latlng,
                  }
              )
          );
      });
      
      window.map.map.on('move', function(e) {
        const bounds=window.map.map.getBounds();
        const result={
          zoom:window.map.map.getZoom(),
          bounds:{
            north_east:bounds.getNorthEast(),
            south_west:bounds.getSouthWest(),
          },
        }
        MapStateListener.postMessage(
              JSON.stringify(result)
          );
      })
  }
);''';
}
