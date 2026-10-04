// A stand-in for the Google Maps platform view, so a screen that draws a
// `GoogleMap` can be pumped in a widget test.
//
// The real thing is an Android/iOS platform view; in `flutter test` there is no
// engine behind it and building one throws. This registers a fake platform whose
// map is a flat coloured box, which is all a *layout* test needs: where the sheet
// and its buttons sit relative to the screen.
//
//   installFakeGoogleMaps();            // before pumping the screen
//   ...
//   await userPansTheMap();             // optional: fires onCameraMoveStarted
//
// `package:google_maps_flutter_platform_interface` is only a transitive
// dependency of the app (google_maps_flutter re-exports just part of it, not the
// platform class), hence the ignore below.

// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Registers the fake for the rest of the test and restores the real platform
/// afterwards. Returns it so a test can drive the "user moved the map" event.
FakeGoogleMapsPlatform installFakeGoogleMaps() {
  final previous = GoogleMapsFlutterPlatform.instance;
  final fake = FakeGoogleMapsPlatform();
  GoogleMapsFlutterPlatform.instance = fake;
  addTearDown(() {
    GoogleMapsFlutterPlatform.instance = previous;
    fake._events.close();
  });
  return fake;
}

/// Answers the `geolocator` method channel with "location off / no permission",
/// so widgets that look up the device position settle on their no-fix path
/// rather than throwing a `MissingPluginException`.
void mockGeolocatorUnavailable(WidgetTester tester) {
  const channel = MethodChannel('flutter.baseflow.com/geolocator');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
      (call) async {
    switch (call.method) {
      case 'isLocationServiceEnabled':
        return false;
      case 'checkPermission':
        return 0; // LocationPermission.denied
    }
    return null;
  });
  addTearDown(() =>
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
}

class FakeGoogleMapsPlatform extends GoogleMapsFlutterPlatform {
  final StreamController<MapEvent<Object?>> _events =
      StreamController<MapEvent<Object?>>.broadcast();

  /// Ids of the maps built so far.
  final List<int> mapIds = [];

  /// What the real map reports when the user drags or pinches it.
  void moveStarted() {
    for (final id in mapIds) {
      _events.add(CameraMoveStartedEvent(id));
    }
  }

  Stream<T> _of<T extends MapEvent<Object?>>(int mapId) =>
      _events.stream.where((e) => e.mapId == mapId && e is T).cast<T>();

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    // `build` runs on every rebuild, but a platform view is only created once.
    if (!mapIds.contains(creationId)) {
      mapIds.add(creationId);
      // The real view reports itself created once the native side is up.
      scheduleMicrotask(() => onPlatformViewCreated(creationId));
    }
    return const ColoredBox(color: Color(0xFFDCE6EE), child: SizedBox.expand());
  }

  @override
  Future<void> init(int mapId) async {}
  @override
  void dispose({required int mapId}) {}
  @override
  Future<void> updateMapConfiguration(MapConfiguration configuration,
          {required int mapId}) async {}
  @override
  Future<void> updateMarkers(MarkerUpdates markerUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updatePolygons(PolygonUpdates polygonUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updatePolylines(PolylineUpdates polylineUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateCircles(CircleUpdates circleUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateHeatmaps(HeatmapUpdates heatmapUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateTileOverlays(
          {required Set<TileOverlay> newTileOverlays,
          required int mapId}) async {}
  @override
  Future<void> updateClusterManagers(ClusterManagerUpdates clusterManagerUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateGroundOverlays(GroundOverlayUpdates groundOverlayUpdates,
          {required int mapId}) async {}
  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate,
          {required int mapId}) async {}
  @override
  Future<void> moveCamera(CameraUpdate cameraUpdate,
          {required int mapId}) async {}

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      _of<CameraMoveStartedEvent>(mapId);
  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) =>
      _of<CameraMoveEvent>(mapId);
  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      _of<CameraIdleEvent>(mapId);
  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      _of<MarkerTapEvent>(mapId);
  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      _of<InfoWindowTapEvent>(mapId);
  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      _of<MarkerDragStartEvent>(mapId);
  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      _of<MarkerDragEvent>(mapId);
  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      _of<MarkerDragEndEvent>(mapId);
  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      _of<PolylineTapEvent>(mapId);
  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      _of<PolygonTapEvent>(mapId);
  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      _of<CircleTapEvent>(mapId);
  @override
  Stream<MapTapEvent> onTap({required int mapId}) =>
      _of<MapTapEvent>(mapId);
  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      _of<MapLongPressEvent>(mapId);
  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      _of<ClusterTapEvent>(mapId);
  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) =>
      _of<GroundOverlayTapEvent>(mapId);
}
