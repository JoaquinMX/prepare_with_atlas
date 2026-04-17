import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/settings/domain/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists [AppPreferences] using [SharedPreferences].
class PreferencesRepository {
  /// Creates a [PreferencesRepository] backed by [_prefs].
  const PreferencesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'app_preferences';

  /// Loads the persisted [AppPreferences], returning defaults on missing or
  /// corrupted data.
  Future<AppPreferences> load() async {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return const AppPreferences();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppPreferences.fromJson(json);
    } catch (_) {
      return const AppPreferences();
    }
  }

  /// Saves [prefs] to persistent storage.
  Future<void> save(AppPreferences prefs) async {
    final json = jsonEncode(prefs.toJson());
    await _prefs.setString(_key, json);
  }
}

/// Provides the [PreferencesRepository].
///
/// Must be overridden in [ProviderScope] with a real [SharedPreferences]
/// instance before the app starts.
final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (_) => throw UnimplementedError(
    'preferencesRepositoryProvider must be overridden with a '
    'PreferencesRepository instance before use.',
  ),
);
