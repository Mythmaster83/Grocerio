import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../../preferences/presentation/providers/preferences_controller.dart';
import '../../../pricing/domain/zip_relevance.dart';
import '../../../sync/presentation/providers/sync_di.dart';
import '../../data/location_precision_store.dart';
import '../../domain/entities/store.dart';
import '../../domain/geo_distance.dart';
import '../providers/stores_di.dart';

/// Pick physical store locations; nearest first when location is available.
///
/// Tracked choices sync with the signed-in account. The location card shows
/// where distances are measured from (approximate or precise GPS).
class TrackedStoresScreen extends ConsumerStatefulWidget {
  const TrackedStoresScreen({super.key});

  @override
  ConsumerState<TrackedStoresScreen> createState() =>
      _TrackedStoresScreenState();
}

class _TrackedStoresScreenState extends ConsumerState<TrackedStoresScreen> {
  final _search = TextEditingController();
  Position? _position;
  String? _placeLabel;
  DateTime? _locationUpdatedAt;
  LocationPrecision _precision = LocationPrecision.approximate;
  String? _locationError;
  bool _locating = false;
  bool _needsPermission = false;
  bool _nearbyOnly = true;

  @override
  void initState() {
    super.initState();
    // Wait until this route has actually painted. Requesting location
    // permission during the push animation pauses the Android activity and
    // left this page blank after the sheet closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_waitForRouteThenBootstrap());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _waitForRouteThenBootstrap() async {
    final animation = ModalRoute.of(context)?.animation;
    if (animation != null && animation.status != AnimationStatus.completed) {
      final done = Completer<void>();
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed && !done.isCompleted) {
          done.complete();
        }
      }

      animation.addStatusListener(listener);
      await Future.any([
        done.future,
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
      animation.removeStatusListener(listener);
    }
    if (mounted) await _bootstrapLocation();
  }

  Future<void> _bootstrapLocation() async {
    final saved = await LocationPrecisionStore.load();
    if (!mounted) return;
    setState(() => _precision = saved);

    final permission = await Geolocator.checkPermission();
    final granted = _isGranted(permission);
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _needsPermission = true;
        _locating = false;
        _locationError = null;
      });
      return;
    }

    await _applyLastKnown();
    await _refreshLocation(precision: saved, requestIfNeeded: false);
  }

  static bool _isGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  LocationAccuracy _accuracyFor(LocationPrecision precision) {
    return switch (precision) {
      LocationPrecision.approximate => LocationAccuracy.low,
      LocationPrecision.precise => LocationAccuracy.high,
    };
  }

  LocationSettings _locationSettings(LocationPrecision precision) {
    final accuracy = _accuracyFor(precision);
    const limit = Duration(seconds: 8);
    if (Platform.isAndroid) {
      return AndroidSettings(accuracy: accuracy, timeLimit: limit);
    }
    return LocationSettings(accuracy: accuracy, timeLimit: limit);
  }

  bool _isUsableLastKnown(Position position) {
    if (!GeoDistance.isPlausible(
      lat: position.latitude,
      lon: position.longitude,
    )) {
      return false;
    }
    final age = DateTime.now().difference(position.timestamp).abs();
    return age < const Duration(minutes: 15);
  }

  Future<void> _applyLastKnown() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null || !mounted) return;
      if (!_isUsableLastKnown(last)) return;
      final label = await _placeLabelFor(last);
      if (!mounted) return;
      setState(() {
        _position = last;
        _placeLabel = label;
        _locationUpdatedAt = last.timestamp;
        _needsPermission = false;
      });
    } catch (_) {
      // Last-known is a fast hint only; a full fix runs next.
    }
  }

  Future<void> _refreshLocation({
    LocationPrecision? precision,
    bool requestIfNeeded = true,
  }) async {
    final mode = precision ?? _precision;
    setState(() {
      _locating = true;
      _locationError = null;
      _precision = mode;
      _needsPermission = false;
    });
    await LocationPrecisionStore.save(mode);

    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _locationError =
              'Turn on location services to sort stores by distance.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!_isGranted(permission) && requestIfNeeded) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _needsPermission = true;
          _locationError =
              'Location permission is off. Enable it in system settings.';
        });
        return;
      }
      if (!_isGranted(permission)) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          _needsPermission = true;
          _locationError = null;
        });
        return;
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: _locationSettings(mode),
        );
      } catch (_) {
        if (mode == LocationPrecision.precise) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: _locationSettings(LocationPrecision.approximate),
          );
          if (mounted) {
            setState(() => _precision = LocationPrecision.approximate);
          }
        } else {
          final last = await Geolocator.getLastKnownPosition();
          if (last == null || !_isUsableLastKnown(last)) rethrow;
          position = last;
        }
      }

      if (!GeoDistance.isPlausible(
        lat: position.latitude,
        lon: position.longitude,
      )) {
        throw StateError('unusable fix');
      }

      final label = await _placeLabelFor(position);
      if (!mounted) return;
      setState(() {
        _position = position;
        _placeLabel = label;
        _locationUpdatedAt = DateTime.now();
        _locating = false;
        _needsPermission = false;
        _locationError = null;
      });
      await _syncPrimaryZipFromTracked();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = 'Could not read your location. Showing tracked stores.';
      });
    }
  }

  Future<String> _placeLabelFor(Position position) async {
    final fromGeo = await _reverseGeocode(position);
    if (fromGeo != null) return fromGeo;
    final stores = ref.read(storesStreamProvider).valueOrNull ?? const <Store>[];
    final nearest = _nearestStoreLabel(position, stores);
    if (nearest != null) return nearest;
    return 'Near ${position.latitude.toStringAsFixed(2)}, '
        '${position.longitude.toStringAsFixed(2)}';
  }

  Future<String?> _reverseGeocode(Position position) async {
    try {
      final geocoding = Geocoding();
      final present = await geocoding.isPresent();
      if (!present) return null;

      final marks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (marks.isEmpty) return null;

      final mark = marks.first;
      final place = _placemarkPlaceName(mark);
      final region = _nonEmpty(mark.administrativeArea);
      if (place != null && region != null) return 'Near $place, $region';
      if (place != null) return 'Near $place';
      if (region != null) return 'Near $region';
    } catch (e, st) {
      logger.warning('Reverse geocode failed: $e');
      logger.error('Reverse geocode stack', e, st);
    }
    return null;
  }

  String? _nearestStoreLabel(Position position, List<Store> stores) {
    Store? best;
    var bestMiles = double.infinity;
    for (final store in stores) {
      if (!store.hasCoordinates) continue;
      final d = GeoDistance.milesBetween(
        lat1: position.latitude,
        lon1: position.longitude,
        lat2: store.latitude!,
        lon2: store.longitude!,
      );
      if (d < bestMiles) {
        bestMiles = d;
        best = store;
      }
    }
    if (best == null) return null;
    final place = best.cityState;
    if (place.isEmpty) return null;
    return 'Near $place';
  }

  /// Prefer suburb/city names; skip generic road placeholders.
  static String? _placemarkPlaceName(Placemark mark) {
    for (final candidate in [
      mark.locality,
      mark.subLocality,
      mark.subAdministrativeArea,
      mark.name,
    ]) {
      final value = _nonEmpty(candidate);
      if (value == null) continue;
      final lower = value.toLowerCase();
      if (lower == 'unnamed road' || lower.startsWith('unnamed ')) continue;
      if (RegExp(r'^\d+$').hasMatch(value)) continue;
      return value;
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _updatedLabel() {
    final at = _locationUpdatedAt;
    if (at == null) return 'not yet updated';
    final seconds = DateTime.now().difference(at).inSeconds;
    if (seconds < 45) return 'updated just now';
    if (seconds < 120) return 'updated 1 min ago';
    if (seconds < 3600) return 'updated ${seconds ~/ 60} min ago';
    return 'updated ${seconds ~/ 3600} hr ago';
  }

  String get _sourceLabel {
    return switch (_precision) {
      LocationPrecision.approximate => 'From approximate location',
      LocationPrecision.precise => 'From device GPS',
    };
  }

  Future<void> _toggle(Store store, bool tracked) async {
    final result = await ref.read(storesRepositoryProvider).setTracked(
          storeId: store.id,
          tracked: tracked,
        );
    if (!mounted) return;
    result.when(
      ok: (_) async {
        await _syncPrimaryZipFromTracked();
      },
      err: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  Future<void> _syncPrimaryZipFromTracked() async {
    final stores = ref.read(storesStreamProvider).valueOrNull ?? const [];
    final tracked = stores.where((s) => s.trackedByUser).toList();
    if (tracked.isEmpty) {
      await ref.read(preferencesControllerProvider.notifier).updatePrefs(
            (p) => p.copyWith(clearPriceZip: true),
          );
      ref.read(syncStatusProvider.notifier).requestSync();
      return;
    }

    Store pick = tracked.first;
    final pos = _position;
    if (pos != null) {
      var best = double.infinity;
      for (final store in tracked) {
        if (!store.hasCoordinates) continue;
        final d = GeoDistance.milesBetween(
          lat1: pos.latitude,
          lon1: pos.longitude,
          lat2: store.latitude!,
          lon2: store.longitude!,
        );
        if (d < best) {
          best = d;
          pick = store;
        }
      }
    }

    final zip = normalizeZip(pick.zip);
    if (zip == null) return;
    await ref.read(preferencesControllerProvider.notifier).updatePrefs(
          (p) => p.copyWith(priceZip: zip),
        );
    ref.read(syncStatusProvider.notifier).requestSync();
  }

  List<_StoreRow> _rows(List<Store> stores) {
    final q = _search.text.trim().toLowerCase();
    final pos = _position;

    final filtered = stores.where((s) {
      if (q.isEmpty) return true;
      final hay =
          '${s.name} ${s.city} ${s.state} ${s.zip} ${s.addressLine}'.toLowerCase();
      return hay.contains(q);
    }).toList();

    final withDistance = <_StoreRow>[
      for (final store in filtered)
        _StoreRow(
          store: store,
          miles: (pos != null &&
                  store.hasCoordinates &&
                  GeoDistance.isPlausible(
                    lat: store.latitude!,
                    lon: store.longitude!,
                  ))
              ? GeoDistance.milesBetween(
                  lat1: pos.latitude,
                  lon1: pos.longitude,
                  lat2: store.latitude!,
                  lon2: store.longitude!,
                )
              : null,
        ),
    ];

    withDistance.sort((a, b) {
      if (a.store.trackedByUser != b.store.trackedByUser) {
        return a.store.trackedByUser ? -1 : 1;
      }
      final am = a.miles;
      final bm = b.miles;
      if (am != null && bm != null) return am.compareTo(bm);
      if (am != null) return -1;
      if (bm != null) return 1;
      return a.store.listLabel.compareTo(b.store.listLabel);
    });

    if (q.isNotEmpty) {
      return withDistance.take(80).toList(growable: false);
    }

    if (_nearbyOnly && pos != null) {
      final nearby = withDistance
          .where((r) => r.miles != null && r.miles! <= 40)
          .toList();
      if (nearby.isNotEmpty) return nearby;
      final nearest = withDistance.where((r) => r.miles != null).toList()
        ..sort((a, b) => a.miles!.compareTo(b.miles!));
      return nearest.take(40).toList(growable: false);
    }

    // Without a GPS fix, do not dump the whole US directory — that freeze is
    // what looked like a blank page. Show tracked locations until they search.
    if (pos == null) {
      final tracked =
          withDistance.where((r) => r.store.trackedByUser).toList();
      if (tracked.isNotEmpty) return tracked;
      return const [];
    }

    return withDistance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storesAsync = ref.watch(storesStreamProvider);

    // Location card is *not* inside storesAsync.when: a slow/empty store
    // stream used to leave this route looking blank.
    return Scaffold(
      appBar: AppBar(title: const Text('Your stores')),
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _position != null
                        ? 'Distances are from the place on the card below.'
                        : 'Track the locations you shop. Comparisons use '
                            'these places.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _LocationCard(
                    locating: _locating,
                    error: _locationError,
                    placeLabel: _placeLabel,
                    sourceLine: _locating && _placeLabel != null
                        ? 'Updating fix · $_sourceLabel'
                        : '$_sourceLabel · ${_updatedLabel()}',
                    precision: _precision,
                    needsPermission: _needsPermission,
                    onUpdate: () => _refreshLocation(),
                    onPrecisionChanged: (mode) =>
                        _refreshLocation(precision: mode),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nearby only (about 40 mi)'),
                    value: _nearbyOnly,
                    onChanged: _position == null
                        ? null
                        : (v) => setState(() => _nearbyOnly = v),
                  ),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search city, chain, or ZIP',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...storesAsync.when(
            data: (stores) {
              final rows = _rows(stores);
              final trackedCount =
                  stores.where((s) => s.trackedByUser).length;
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _position != null
                          ? '$trackedCount tracked · ${rows.length} shown'
                          : trackedCount == 0
                              ? 'Search a city or ZIP, or turn on location.'
                              : '$trackedCount tracked. Search to add more.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                if (rows.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      child: Text(
                        _search.text.trim().isNotEmpty
                            ? 'No stores match. Try another city or ZIP.'
                            : _position == null
                                ? 'No stores yet. Use location or search.'
                                : 'No stores match. Try clearing nearby-only.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return _StoreTile(
                          store: row.store,
                          distance: row.miles == null
                              ? null
                              : GeoDistance.formatMiles(
                                  row.miles!,
                                  approximate: _precision ==
                                      LocationPrecision.approximate,
                                ),
                          onToggle: (v) => _toggle(row.store, v),
                        );
                      },
                    ),
                  ),
              ];
            },
            loading: () => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            error: (error, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    error is AppFailure
                        ? error.message
                        : 'Could not load stores.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool locating;
  final String? error;
  final String? placeLabel;
  final String sourceLine;
  final LocationPrecision precision;
  final bool needsPermission;
  final VoidCallback onUpdate;
  final ValueChanged<LocationPrecision> onPrecisionChanged;

  const _LocationCard({
    required this.locating,
    required this.error,
    required this.placeLabel,
    required this.sourceLine,
    required this.precision,
    required this.needsPermission,
    required this.onUpdate,
    required this.onPrecisionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: locating && placeLabel == null && error == null
                      ? Text(
                          'Finding your location…',
                          style: theme.textTheme.titleSmall,
                        )
                      : error != null && placeLabel == null
                          ? Text(
                              error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            )
                          : needsPermission && placeLabel == null
                              ? Text(
                                  'Use your location to measure distances '
                                  'to stores.',
                                  style: theme.textTheme.bodyMedium,
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      placeLabel ??
                                          (locating
                                              ? 'Finding your location…'
                                              : 'Location unknown'),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      error ?? sourceLine,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: error != null
                                            ? theme.colorScheme.error
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: locating ? null : onUpdate,
                  child: locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(needsPermission ? 'Use location' : 'Update'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('Approximate'),
                  selected: precision == LocationPrecision.approximate,
                  onSelected: locating
                      ? null
                      : (_) => onPrecisionChanged(
                            LocationPrecision.approximate,
                          ),
                ),
                ChoiceChip(
                  label: const Text('Precise'),
                  selected: precision == LocationPrecision.precise,
                  onSelected: locating
                      ? null
                      : (_) =>
                          onPrecisionChanged(LocationPrecision.precise),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final Store store;
  final String? distance;
  final ValueChanged<bool> onToggle;

  const _StoreTile({
    required this.store,
    required this.distance,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted);
    final address = store.subtitle;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name, style: theme.textTheme.titleSmall),
                  if (distance != null) ...[
                    const SizedBox(height: 2),
                    Text(distance!, style: muted),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(address, style: muted),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    store.trackedByUser
                        ? 'On · used in comparisons'
                        : 'Off',
                    style: muted,
                  ),
                ],
              ),
            ),
            Switch(value: store.trackedByUser, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

class _StoreRow {
  final Store store;
  final double? miles;

  const _StoreRow({required this.store, required this.miles});
}
