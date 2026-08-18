import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/location/location_service.dart';
import '../../../core/widgets/mc.dart';
import '../models/place.dart';
import '../models/place_prediction.dart';
import '../providers/search_history_provider.dart';
import '../services/maps_service.dart';

/// Address search — live Google Places autocomplete. Pick a suggestion to see
/// the route to it on the map (`/route-preview`).
class SetRouteScreen extends ConsumerStatefulWidget {
  const SetRouteScreen({super.key});

  @override
  ConsumerState<SetRouteScreen> createState() => _SetRouteScreenState();
}

class _SetRouteScreenState extends ConsumerState<SetRouteScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  LatLng? _origin; // current location, used to bias suggestions

  List<PlacePrediction> _results = const [];
  bool _loading = false;
  bool _resolving = false; // fetching details after a tap
  String? _error;

  static const _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _primeOrigin();
  }

  Future<void> _primeOrigin() async {
    try {
      final pos = await _locationService.currentPosition();
      if (mounted) setState(() => _origin = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // Bias is best-effort — search still works without it.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    try {
      final res = await ref
          .read(googleMapsServiceProvider)
          .autocomplete(query, origin: _origin);
      if (!mounted || query != _ctrl.text) return;
      setState(() {
        _results = res;
        _loading = false;
        _error = null;
      });
    } on MapsServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _select(PlacePrediction p) async {
    setState(() => _resolving = true);
    try {
      final place = await ref.read(googleMapsServiceProvider).placeDetails(p.placeId);
      if (!mounted) return;
      await ref.read(searchHistoryProvider.notifier).add(place);
      if (!mounted) return;
      setState(() => _resolving = false);
      context.push('/route-preview', extra: place);
    } on MapsServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = e.message;
      });
    }
  }

  /// A recent destination is already a resolved [Place] — skip the details
  /// round-trip and go straight to the route preview. Re-adding bumps it to the
  /// top of the list.
  void _openRecent(Place place) {
    ref.read(searchHistoryProvider.notifier).add(place);
    context.push('/route-preview', extra: place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.paper,
      body: Column(
        children: [
          Container(
            color: Brand.paper,
            padding: const EdgeInsets.fromLTRB(18, 60, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const McNavHeader(title: 'Plan your trip', fallback: '/home'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
                          ),
                          Container(
                            width: 2,
                            height: 70,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Brand.line,
                          ),
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Brand.blue,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          const McField(icon: 'pin', value: 'Current location'),
                          const SizedBox(height: 8),
                          McField(
                            icon: 'search',
                            controller: _ctrl,
                            placeholder: 'Where to?',
                            editable: true,
                            autofocus: true,
                            onChanged: _onChanged,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_resolving || _loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Brand.blue),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: tw(FontWeight.w700, 14, Brand.sub),
              ),
              const SizedBox(height: 16),
              _SetOnMapRow(onTap: () => context.push('/pick-on-map', extra: _origin)),
            ],
          ),
        ),
      );
    }
    if (_ctrl.text.trim().isEmpty) {
      return _buildRecents();
    }
    if (_results.isEmpty) {
      return _NoMatchesOnMapCard(
        onSetPin: () => context.push('/pick-on-map', extra: _origin),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      itemCount: _results.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _SetOnMapRow(
            onTap: () => context.push('/pick-on-map', extra: _origin),
          );
        }
        final prediction = _results[i - 1];
        return _SuggestionRow(
          prediction: prediction,
          onTap: () => _select(prediction),
        );
      },
    );
  }

  /// Empty-query state: the rider's recent destinations (most-recent first),
  /// with a prominent "Set pin on map" option.
  Widget _buildRecents() {
    final recents = ref.watch(searchHistoryProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      children: [
        _SetOnMapRow(
          onTap: () => context.push('/pick-on-map', extra: _origin),
        ),
        if (recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent', style: tw(FontWeight.w800, 13, Brand.sub)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(searchHistoryProvider.notifier).clear(),
                  child: Text('Clear', style: tw(FontWeight.w800, 13, Brand.blue)),
                ),
              ],
            ),
          ),
          for (final place in recents)
            _RecentRow(place: place, onTap: () => _openRecent(place)),
        ],
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.place, this.onTap});
  final Place place;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Brand.fill)),
        ),
        child: Row(
          children: [
            const Ico('clock', size: 20, color: Brand.sub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tw(FontWeight.w800, 14.5)),
                  if (place.address.isNotEmpty)
                    Text(place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tw(FontWeight.w600, 12.5, Brand.sub)),
                ],
              ),
            ),
            const Ico('chevR', size: 18, color: Brand.faint),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.prediction, this.onTap});
  final PlacePrediction prediction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Brand.fill)),
        ),
        child: Row(
          children: [
            const Ico('pin', size: 20, color: Brand.sub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prediction.primaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tw(FontWeight.w800, 14.5)),
                  if (prediction.secondaryText.isNotEmpty)
                    Text(prediction.secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tw(FontWeight.w600, 12.5, Brand.sub)),
                ],
              ),
            ),
            const Ico('chevR', size: 18, color: Brand.faint),
          ],
        ),
      ),
    );
  }
}

class _SetOnMapRow extends StatelessWidget {
  const _SetOnMapRow({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Brand.blue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Brand.blue.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Brand.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Ico('pin', size: 18, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set pin on map', style: tw(FontWeight.w800, 14.5, Brand.blue)),
                  const SizedBox(height: 2),
                  Text('Drag & pinpoint your exact location',
                      style: tw(FontWeight.w600, 12, Brand.sub)),
                ],
              ),
            ),
            const Ico('chevR', size: 18, color: Brand.blue),
          ],
        ),
      ),
    );
  }
}

class _NoMatchesOnMapCard extends StatelessWidget {
  const _NoMatchesOnMapCard({this.onSetPin});
  final VoidCallback? onSetPin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Brand.fill,
                shape: BoxShape.circle,
              ),
              child: const Ico('search', size: 28, color: Brand.sub),
            ),
            const SizedBox(height: 16),
            Text('No matching suggestions', style: tw(FontWeight.w800, 16)),
            const SizedBox(height: 6),
            Text(
              "Can't find this address in suggestions? Point and drop a pin on the map to set your exact spot.",
              textAlign: TextAlign.center,
              style: tw(FontWeight.w600, 13, Brand.sub),
            ),
            const SizedBox(height: 20),
            McButton('Set pin on map', onTap: onSetPin),
          ],
        ),
      ),
    );
  }
}
