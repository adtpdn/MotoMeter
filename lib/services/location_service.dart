import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../database/fuel_database.dart';

class LocationService {
  final _speedController = StreamController<double>.broadcast();
  Stream<double> get speedStream => _speedController.stream;

  final _distanceController = StreamController<double>.broadcast();
  Stream<double> get tripDistanceStream => _distanceController.stream;

  final _locationController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get locationStream => _locationController.stream;

  double _currentTripDistance = 0.0;
  Position? _lastPosition;
  
  LatLng? get currentLocation => _lastPosition != null 
    ? LatLng(_lastPosition!.latitude, _lastPosition!.longitude) 
    : null;
  
  StreamSubscription<Position>? _positionSubscription;

  void startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    await _positionSubscription?.cancel();
    
    // Optimized settings for Android real-time speed
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "MotoMeter is tracking your journey",
          notificationTitle: "Real-time Tracking Active",
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      // Speed calculation (Geolocator provides speed in m/s)
      double speedKmh = position.speed * 3.6;
      
      // Smoothing: ignore < 0.5 km/h
      if (speedKmh < 0.5) speedKmh = 0.0;
      
      _speedController.add(speedKmh);

      // Distance calculation
      if (_lastPosition != null) {
        double distanceBetween = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        
        // Accumulate distance (more sensitive for testing/slow movement)
        if (distanceBetween > 0.5) {
          _currentTripDistance += (distanceBetween / 1000.0);
          _distanceController.add(_currentTripDistance);
        }
      }
      _locationController.add(LatLng(position.latitude, position.longitude));
      _lastPosition = position;
    });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
  }

  void resetTrip() {
    _currentTripDistance = 0.0;
    _distanceController.add(0.0);
  }

  Future<void> _recordTrip(String startName, String endName, double destLat, double destLon, double dist) async {
    final db = FuelDatabase.instance;
    await db.insertTrip({
      'start_name': startName,
      'end_name': endName,
      'dest_lat': destLat,
      'dest_lon': destLon,
      'timestamp': DateTime.now().toIso8601String(),
      'distance_km': dist,
    });
  }

  Future<Map<String, double>> saveCurrentOdometer(
    String startName, String endName, double destLat, double destLon, double plannedDist
  ) async {
    final db = FuelDatabase.instance;
    
    // Use the actual GPS distance if recorded, otherwise fallback to planned distance 
    // if the user finished the trip with zero GPS movement (useful for simulators/low signal).
    double finalDistance = _currentTripDistance > 0 ? _currentTripDistance : plannedDist;

    double currentTotal = await db.getLifetimeOdometer();
    double newTotal = currentTotal + finalDistance;
    await db.saveSetting('odo_lifetime', newTotal.toString());
    
    // Reduce fuel based on distance
    double currentLiters = await db.getCurrentLiters();
    double ratio = await db.getFuelRatio();
    double consumed = ratio > 0 ? (finalDistance / ratio) : 0;
    double newLiters = (currentLiters - consumed).clamp(0, 100);
    await db.saveCurrentLiters(newLiters);
    
    // Save to history
    await _recordTrip(startName, endName, destLat, destLon, finalDistance);
    
    resetTrip();

    return {
      'new_odo': newTotal,
      'new_liters': newLiters,
    };
  }

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    return await Geolocator.getCurrentPosition();
  }

  void dispose() {
    _speedController.close();
    _distanceController.close();
    _locationController.close();
    _positionSubscription?.cancel();
  }
}
