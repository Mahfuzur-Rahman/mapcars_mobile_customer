import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/brand.dart';
import '../../models/directions_result.dart';
import '../../models/place.dart';

/// The rider's actual pickup → drop-off on a real Google map.
///
/// Draws the route already fetched on the preview screen and carried in
/// `RideFlowState.route`, so it costs **no** Directions call. With no route
/// stored (a resumed trip, say) it still shows both real ends and fits the
/// camera to them — just without the line between.
///
/// This replaces the decorative `MapBackground` the choose-ride / confirm /
/// searching screens used to sit on, whose painted road layout and pins bore no
/// relation to where the rider was actually going.
class StaticRouteMap extends StatefulWidget {
  const StaticRouteMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.route,
  });

  final Place pickup;
  final Place dropoff;
  final DirectionsResult? route;

  @override
  State<StaticRouteMap> createState() => _StaticRouteMapState();
}

class _StaticRouteMapState extends State<StaticRouteMap> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StaticRouteMap old) {
    super.didUpdateWidget(old);
    if (old.pickup != widget.pickup ||
        old.dropoff != widget.dropoff ||
        old.route != widget.route) {
      _fitBounds();
    }
  }

  LatLng get _pickup => LatLng(widget.pickup.lat, widget.pickup.lng);
  LatLng get _dropoff => LatLng(widget.dropoff.lat, widget.dropoff.lng);

  /// The fetched route's own bounds when we have one, otherwise a box around
  /// the two ends.
  LatLngBounds get _bounds {
    final route = widget.route;
    if (route != null && route.points.length >= 2) return route.bounds;
    return LatLngBounds(
      southwest: LatLng(
        math.min(_pickup.latitude, _dropoff.latitude),
        math.min(_pickup.longitude, _dropoff.longitude),
      ),
      northeast: LatLng(
        math.max(_pickup.latitude, _dropoff.latitude),
        math.max(_pickup.longitude, _dropoff.longitude),
      ),
    );
  }

  Future<void> _fitBounds() async {
    final controller = _controller;
    if (controller == null) return;
    // The bottom sheet covers roughly half the screen on these routes, so pad
    // generously rather than centring the line behind it.
    await controller.animateCamera(CameraUpdate.newLatLngBounds(_bounds, 72));
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.route?.points ?? const <LatLng>[];

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _pickup, zoom: 13),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
              title: 'Pickup', snippet: widget.pickup.label),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoff,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
              title: 'Drop-off', snippet: widget.dropoff.label),
        ),
      },
      polylines: {
        if (points.length >= 2)
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Brand.blue,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      },
      onMapCreated: (c) {
        _controller = c;
        _fitBounds();
      },
    );
  }
}
