import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'logger.dart' show log;
import 'proto/pneumacore.pb.dart';

abstract class GeoException implements Exception {
  final String message;
  GeoException(this.message);
}

class GeoServiceDisabledException extends GeoException {
  GeoServiceDisabledException() : super('GPS is disabled on this device');
}

class GeoPermissionDeniedException extends GeoException {
  GeoPermissionDeniedException() : super('Location permissions are denied');
}

class GeoPermissionDeniedForeverException extends GeoException {
  GeoPermissionDeniedForeverException()
    : super('Location permissions are permanently denied');
}

Future<void> checkPermissions() async {
  LocationPermission permission;

  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw GeoServiceDisabledException();
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw GeoPermissionDeniedException();
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw GeoPermissionDeniedForeverException();
  }
}

enum GeoStatus {
  initial,
  loading,
  tracking,
  disabled,
  denied,
  deniedForever,
  unknownError,
}

class MyGeoService {
  static final MyGeoService _instance = MyGeoService._internal();
  factory MyGeoService() => _instance;
  MyGeoService._internal();

  final distanceFilter = 1;
  final intervalDuration = const Duration(seconds: 5);

  final ValueNotifier<Position?> currentPosition = ValueNotifier(null);
  final ValueNotifier<GeoStatus> status = ValueNotifier(GeoStatus.initial);

  StreamSubscription<Position>? _positionStream;
  Timer? _fallbackTimer;

  Future<void> startTracking() async {
    stopTracking();
    status.value = GeoStatus.loading;

    try {
      await checkPermissions();
      _initAdaptiveStreams();
    } on GeoServiceDisabledException {
      status.value = GeoStatus.disabled;
    } on GeoPermissionDeniedException {
      status.value = GeoStatus.denied;
    } on GeoPermissionDeniedForeverException {
      status.value = GeoStatus.deniedForever;
    } catch (e) {
      status.value = GeoStatus.unknownError;
    }
  }

  void _initAdaptiveStreams() {
    bool gotPosition = false;

    // настройки для быстрой выдачи, но если есть связь
    final settings = AndroidSettings(
      // accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
      intervalDuration: intervalDuration,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
          gotPosition = true;
          _fallbackTimer?.cancel();
          status.value = GeoStatus.tracking;
          // if (pos.accuracy > 10.0) {
          //   log.i(
          //     'Got position with low accuracy (${pos.accuracy}m), waiting for better fix...',
          //   );
          //   return;
          // }
          currentPosition.value = pos;
        }, onError: _handleStreamError);

    _fallbackTimer = Timer(const Duration(seconds: 10), () {
      if (!gotPosition) {
        log.i('Failed to get location quickly, trying slower method...');
        _switchPositionStream();
      }
    });
  }

  void _switchPositionStream() {
    _positionStream?.cancel();

    // настройки для медленной выдачи, но без связи, через чип GPS
    final settings = AndroidSettings(
      forceLocationManager: true,
      // accuracy: LocationAccuracy.high,
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
      intervalDuration: intervalDuration,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
          status.value = GeoStatus.tracking;
          // if (pos.accuracy > 10.0) {
          //   log.i(
          //     'Got position with low accuracy (${pos.accuracy}m), waiting for better fix...',
          //   );
          //   return;
          // }
          currentPosition.value = pos;
        }, onError: _handleStreamError);
  }

  void _handleStreamError(Object error) {
    log.e('Got error while tracking: $error');
    stopTracking();
    status.value = GeoStatus.denied; 
  }

  void stopTracking() {
    _positionStream?.cancel();
    _fallbackTimer?.cancel();
    _positionStream = null;
  }
}

Future<Position> getLocation() async {
  await checkPermissions();
  return await _smartGetLocation();
}

Future<Position> _smartGetLocation() async {
  try {
    // может выдать быстро, но только если есть связь
    return await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      ),
    );
  } on TimeoutException {
    // выдает медленно, но даже без связи напрямую через чип GPS
    log.i('Failed to get location quickly, trying slower method...');
    return await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        forceLocationManager: true,
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      ),
    );
  } catch (e) {
    rethrow;
  }
}

(double, double) getDistanceAndBearing(Position myPos, PositionInfo targetPos) {
  // расстояние в метрах
  double dist = Geolocator.distanceBetween(
    myPos.latitude,
    myPos.longitude,
    targetPos.latitude,
    targetPos.longitude,
  );

  // азимут в градусах от -180 до 180
  double bearing = Geolocator.bearingBetween(
    myPos.latitude,
    myPos.longitude,
    targetPos.latitude,
    targetPos.longitude,
  );

  return (dist, bearing);
}
