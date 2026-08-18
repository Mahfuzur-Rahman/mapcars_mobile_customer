import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/location/location_service.dart';
import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../models/place.dart';
import '../providers/search_history_provider.dart';
import '../services/maps_service.dart';

/// Interactive map screen allowing the rider to pan, drag, and drop a pin
/// to pinpoint their exact desired location (e.g. alleyways, unmarked spots,
/// or places not in Google suggestions) with automatic reverse geocoding.
class PickOnMapScreen extends ConsumerStatefulWidget {
  const PickOnMapScreen({super.key, this.initialPosition});

  final LatLng? initialPosition;

  @override
  ConsumerState<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends ConsumerState<PickOnMapScreen> {
  GoogleMapController? _mapController;
  static const _locationService = LocationService();

  // Bournemouth city center fallback
  static const LatLng _bournemouth = LatLng(50.7192, -1.8808);

  LatLng _currentCenter = _bournemouth;
  Place? _resolvedPlace;
  bool _isLocating = false;
  bool _isResolvingAddress = false;
  bool _isMoving = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentCenter = widget.initialPosition!;
    }
    _initLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (widget.initialPosition != null) {
      _reverseGeocode(widget.initialPosition!);
      return;
    }

    try {
      final pos = await _locationService.currentPosition();
      final target = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _currentCenter = target);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.5));
        _reverseGeocode(target);
      }
    } catch (_) {
      _reverseGeocode(_currentCenter);
    }
  }

  Future<void> _recenterToGps() async {
    setState(() => _isLocating = true);
    try {
      final pos = await _locationService.currentPosition();
      final target = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _currentCenter = target);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.5));
        _reverseGeocode(target);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not obtain current GPS location.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
  }

  void _onCameraMoveStarted() {
    if (!_isMoving) {
      setState(() => _isMoving = true);
    }
    _debounceTimer?.cancel();
  }

  void _onCameraIdle() {
    if (_isMoving) {
      setState(() => _isMoving = false);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _reverseGeocode(_currentCenter);
    });
  }

  Future<void> _reverseGeocode(LatLng target) async {
    if (!mounted) return;
    setState(() => _isResolvingAddress = true);
    try {
      final place = await ref.read(googleMapsServiceProvider).reverseGeocode(target);
      if (mounted) {
        setState(() {
          _resolvedPlace = place;
          _isResolvingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedPlace = Place(
            label: 'Selected location',
            address:
                '${target.latitude.toStringAsFixed(5)}, ${target.longitude.toStringAsFixed(5)}',
            lat: target.latitude,
            lng: target.longitude,
          );
          _isResolvingAddress = false;
        });
      }
    }
  }

  void _confirmSelection() {
    final place = _resolvedPlace ??
        Place(
          label: 'Selected location',
          address:
              '${_currentCenter.latitude.toStringAsFixed(5)}, ${_currentCenter.longitude.toStringAsFixed(5)}',
          lat: _currentCenter.latitude,
          lng: _currentCenter.longitude,
        );

    ref.read(searchHistoryProvider.notifier).add(place);
    context.push('/route-preview', extra: place);
  }

  @override
  Widget build(BuildContext context) {
    final place = _resolvedPlace;
    final label = place?.label ?? (_isResolvingAddress ? 'Pinning location…' : 'Selected location');
    final address = place?.address ??
        (_isResolvingAddress
            ? 'Finding nearby address…'
            : '${_currentCenter.latitude.toStringAsFixed(5)}, ${_currentCenter.longitude.toStringAsFixed(5)}');

    return Scaffold(
      backgroundColor: Brand.bg,
      body: Stack(
        children: [
          // Fullscreen Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 16.5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (ctrl) {
              _mapController = ctrl;
            },
            onCameraMoveStarted: _onCameraMoveStarted,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),

          // Precision Center Pin with Floating & Bounce Animation
          Center(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, _isMoving ? -24 : -12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Brand.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Brand.blue.withOpacity(0.4),
                            blurRadius: _isMoving ? 16 : 8,
                            spreadRadius: _isMoving ? 3 : 1,
                            offset: Offset(0, _isMoving ? 12 : 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Ground contact dot
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _isMoving ? 0.3 : 0.8,
                      child: Container(
                        width: 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Header Floating Navigation
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => backOr(context, '/set-route'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Brand.fill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Ico('chevL', size: 18, color: Brand.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Drag map to set pin',
                          style: tw(FontWeight.w900, 15),
                        ),
                        Text(
                          'Point to your exact destination',
                          style: tw(FontWeight.w600, 12, Brand.sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating GPS Recenter FAB
          Positioned(
            bottom: 220,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'recenter_gps_fab',
              onPressed: _isLocating ? null : _recenterToGps,
              backgroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: _isLocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.blue),
                    )
                  : const Icon(Icons.my_location_rounded, color: Brand.blue, size: 24),
            ),
          ),

          // Bottom Location Card Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Brand.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Ico('pin', size: 22, color: Brand.blue),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tw(FontWeight.w900, 16.5),
                                  ),
                                ),
                                if (_isResolvingAddress) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Brand.blue,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tw(FontWeight.w600, 13, Brand.sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  McButton(
                    'Confirm this location',
                    onTap: _confirmSelection,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
