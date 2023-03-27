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
  Logger createLoggerFor(MapEvent event) {
    return Logger('${_logger.fullName}.${event.runtimeType}');
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
      final logger = createLoggerFor(event);
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
            logger.warning('preventing navigation to ${request.url}');
            return NavigationDecision.prevent;
          },
        ),
      );
      await controller.addJavaScriptChannel(
        'TapListener',
        onMessageReceived: (JavaScriptMessage message) {
          logger.info('message received from channel:\n${message.message}');
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          add(_InternalEmitter(MapTapState.fromMap(data)));
        },
      );
      await controller.addJavaScriptChannel(
        'MapStateListener',
        onMessageReceived: (JavaScriptMessage message) {
          Debounce.debounce(
            'MapStateListener',
            const Duration(milliseconds: 350),
            () {
              logger.info('message received from channel:\n${message.message}');
              final data = jsonDecode(message.message) as Map<String, dynamic>;
              logger.info('state updated to $data');
              add(_InternalEmitter(MapStateChanged.fromMap(data)));
            },
          );
        },
      );
      await controller.loadHtmlString(
        _pageCode,
        baseUrl: baseMapUri.toString(),
      );
      logger.fine('loading html page at `${DateTime.now()}`');
      // Future.delayed(const Duration(milliseconds: 300));
      // WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      //   await Future.delayed(const Duration(seconds: 1));
      //   logger.fine('injecting initializer script at `${DateTime.now()}`');
      //   await controller.runJavaScriptReturningResult(_initializerScript);
      // });
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
        final logger = createLoggerFor(event);

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
