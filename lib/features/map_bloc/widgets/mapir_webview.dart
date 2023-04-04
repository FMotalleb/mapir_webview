import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:mapir_webview/features/debouncer/debouncer.dart';
import 'package:mapir_webview/features/map_bloc/bloc/map_bloc.dart';
part '../event_sink/event_sink.dart';

class MapIrWebView extends StatelessWidget {
  const MapIrWebView({
    Key? key,
    required this.mapIrToken,
    this.initialLocation,
    this.initialZoomLevel = 6,
    this.loggerName = 'MapIRWebView',
    required this.controller,
    this.baseMapUri,
    this.styles,
    this.scripts,
    this.stateListener,
    this.placeholder,
  }) : super(key: key);
  final String mapIrToken;
  final LatLng? initialLocation;
  final double initialZoomLevel;
  final String loggerName;
  final MapDriver controller;
  final Uri? baseMapUri;

  final List<String>? styles;
  final List<String>? scripts;
  final void Function(BuildContext context, MapState state)? stateListener;
  final Widget Function(BuildContext context)? placeholder;
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = MapBloc(
          mapIrToken: mapIrToken,
          initialZoom: initialZoomLevel,
          initialPoint: initialLocation ?? LatLng(32, 53),
          baseMapUri: baseMapUri ?? Uri.parse('https://map.ir/'),
          loggerName: loggerName,
          scripts: scripts,
          styles: styles,
        );
        bloc.add(RequestMapControllerEvent());
        controller._map = bloc;
        return bloc;
      },
      child: _MapView(
        key: key,
        placeholder: placeholder,
        stateListener: stateListener,
        controller: controller,
      ),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView({
    super.key,
    required this.stateListener,
    required this.placeholder,
    required this.controller,
  });

  final MapDriver controller;
  final void Function(BuildContext context, MapState state)? stateListener;
  final Widget Function(BuildContext context)? placeholder;
  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  Offset? lastTapOffset;
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MapBloc, MapState>(
      listener: (context, state) {
        widget.controller._stateChanged(state);
        widget.stateListener?.call(context, state);
      },
      buildWhen: (previous, current) => current is MapBlocCreatedMapController,
      builder: (context, state) {
        if (state is! MapBlocCreatedMapController) {
          return widget.placeholder?.call(context) ?? const SizedBox();
        }
        return Listener(
          onPointerDown: (event) {
            const tag = 'double_tap_validator';
            final tapped = Debounce.cancel(tag);
            final deltaPoint = lastTapOffset?.translate(-1 * event.localPosition.dx, -1 * event.localPosition.dy);
            if (deltaPoint != null && tapped && deltaPoint.distance < 100) {
              Debounce.cancel('tap_event_reserve');
              context.read<MapBloc>().add(ZoomInEvent(event.hashCode));
            } else {
              Debounce.debounce(tag, const Duration(milliseconds: 150), () {});
            }
            lastTapOffset = event.localPosition;
          },
          child: WebViewWidget(
            controller: state.controller,
          ),
        );
      },
    );
  }
}
