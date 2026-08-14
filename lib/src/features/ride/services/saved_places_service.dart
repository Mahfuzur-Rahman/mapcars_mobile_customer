import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/prefs.dart';
import '../models/place.dart';

class SavedPlaces {
  const SavedPlaces({this.home, this.work});

  final Place? home;
  final Place? work;

  SavedPlaces copyWith({Place? home, Place? work}) => SavedPlaces(
        home: home ?? this.home,
        work: work ?? this.work,
      );
}

class SavedPlacesService {
  SavedPlacesService(this._prefs);

  final SharedPreferences _prefs;

  static const _homeKey = 'saved_place_home';
  static const _workKey = 'saved_place_work';

  Place? getHome() {
    final raw = _prefs.getString(_homeKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Place? getWork() {
    final raw = _prefs.getString(_workKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setHome(Place place) async {
    await _prefs.setString(_homeKey, jsonEncode(place.toJson()));
  }

  Future<void> setWork(Place place) async {
    await _prefs.setString(_workKey, jsonEncode(place.toJson()));
  }

  SavedPlaces loadAll() => SavedPlaces(
        home: getHome(),
        work: getWork(),
      );
}

final savedPlacesServiceProvider = Provider<SavedPlacesService>(
  (ref) => SavedPlacesService(ref.watch(sharedPreferencesProvider)),
);

final savedPlacesNotifierProvider =
    StateNotifierProvider<SavedPlacesNotifier, SavedPlaces>((ref) {
  final service = ref.watch(savedPlacesServiceProvider);
  return SavedPlacesNotifier(service);
});

class SavedPlacesNotifier extends StateNotifier<SavedPlaces> {
  SavedPlacesNotifier(this._service) : super(_service.loadAll());

  final SavedPlacesService _service;

  Future<void> setHome(Place place) async {
    await _service.setHome(place);
    state = state.copyWith(home: place);
  }

  Future<void> setWork(Place place) async {
    await _service.setWork(place);
    state = state.copyWith(work: place);
  }
}
