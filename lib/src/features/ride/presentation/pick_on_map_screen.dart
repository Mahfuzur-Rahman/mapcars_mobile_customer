import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/location/location_service.dart';
import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../models/place.dart';
import '../models/place_prediction.dart';
import '../providers/search_history_provider.dart';
import '../services/maps_service.dart';

/// Interactive map screen allowing the rider to pan, drag, and drop a pin
/// to pinpoint their exact desired location (e.g. alleyways, unmarked spots,
/// or places not in Google suggestions) with automatic reverse geocoding.
///
/// Search lives here too, on the same map. Searching on one screen and then
/// landing on a different one meant you could never see where a result
/// actually was before committing to it, and adjusting it afterwards meant
/// going back and starting again. Here a suggestion just flies the pin to the
/// place, and the pin stays adjustable — search to get close, drag to get it
/// exact.
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

  // ── Search ──────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  List<PlacePrediction> _predictions = const [];
  bool _searching = false;
  String? _searchError;

  /// True once a search result has been applied and the camera has not been
  /// moved since. Used only to keep the header copy honest — "drag to adjust"
  /// rather than "drag map to set pin".
  bool _fromSearch = false;

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
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _predictions = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    // Autocomplete is billed per keystroke-burst, so coalesce typing the same
    // way the Set route screen does.
    _searchDebounce = Timer(const Duration(milliseconds: 350), () => _runSearch(q));
  }

  Future<void> _runSearch(String query) async {
    try {
      final res = await ref
          .read(googleMapsServiceProvider)
          .autocomplete(query, origin: _currentCenter);
      if (!mounted || query != _searchCtrl.text.trim()) return;
      setState(() {
        _predictions = res;
        _searching = false;
        _searchError = null;
      });
    } on MapsServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _predictions = const [];
        _searching = false;
        _searchError = e.message;
      });
    }
  }

  /// Fly the pin to a searched place. The result is adopted as the resolved
  /// place directly — Google's own name/address for it is better than what
  /// reverse-geocoding the same coordinate would give back.
  Future<void> _applyPrediction(PlacePrediction p) async {
    _searchFocus.unfocus();
    setState(() {
      _searching = true;
      _predictions = const [];
    });
    try {
      final place = await ref.read(googleMapsServiceProvider).placeDetails(p.placeId);
      if (!mounted) return;
      final target = LatLng(place.lat, place.lng);
      setState(() {
        _currentCenter = target;
        _resolvedPlace = place;
        _isResolvingAddress = false;
        _searching = false;
        _fromSearch = true;
        _searchCtrl.text = place.label;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 17)),
      );
    } on MapsServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.message;
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _predictions = const [];
      _searching = false;
      _searchError = null;
    });
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
    if (_fromSearch) _fromSearch = false;
    if (_searchFocus.hasFocus) _searchFocus.unfocus();
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

          // Top: back + address search, with suggestions dropping over the map.
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          style: tw(FontWeight.w700, 14.5),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Search an address or place',
                            hintStyle: tw(FontWeight.w600, 14, Brand.faint),
                          ),
                        ),
                      ),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Brand.blue),
                          ),
                        )
                      else if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _clearSearch,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close_rounded,
                                size: 20, color: Brand.sub),
                          ),
                        ),
                    ],
                  ),
                ),

                // Suggestions. Capped and scrollable so a long list can never
                // cover the pin the rider is trying to place.
                if (_predictions.isNotEmpty || _searchError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 232),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _searchError != null
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(_searchError!,
                                style: tw(FontWeight.w600, 12.5, Brand.sub)),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: _predictions.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: Brand.line.withValues(alpha: 0.5),
                              indent: 46,
                            ),
                            itemBuilder: (_, i) {
                              final p = _predictions[i];
                              return InkWell(
                                onTap: () => _applyPrediction(p),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      const Ico('pin', size: 18, color: Brand.sub),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(p.primaryText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: tw(FontWeight.w800, 14)),
                                            if (p.secondaryText.isNotEmpty)
                                              Text(p.secondaryText,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: tw(FontWeight.w600, 12,
                                                      Brand.sub)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.open_with_rounded, size: 14, color: Brand.faint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _fromSearch
                              ? 'Drag the map to fine-tune this spot'
                              : 'Drag the map to move the pin',
                          style: tw(FontWeight.w600, 11.5, Brand.faint),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
