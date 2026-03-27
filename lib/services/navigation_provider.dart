import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../database/fuel_database.dart';

class NavigationProvider extends ChangeNotifier {
  String? _startName;
  String? _endName;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  double _targetDistance = 0;

  String? get startName => _startName;
  String? get endName => _endName;
  LatLng? get destination => _destination;
  List<LatLng> get routePoints => _routePoints;
  double get targetDistance => _targetDistance;

  bool get hasActiveRoute => _destination != null;

  NavigationProvider() {
    _loadState();
  }

  Future<void> _loadState() async {
    final db = FuelDatabase.instance;
    _startName = await db.getSetting('nav_start_name');
    _endName = await db.getSetting('nav_end_name');
    final lat = await db.getSetting('nav_dest_lat');
    final lng = await db.getSetting('nav_dest_lng');
    
    if (lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty) {
      _destination = LatLng(double.parse(lat), double.parse(lng));
    }
    final dist = await db.getSetting('nav_target_dist');
    _targetDistance = double.tryParse(dist ?? '0') ?? 0;
    notifyListeners();
  }

  Future<void> bindDestination(String start, String end, LatLng dest, double distance, List<LatLng> points) async {
    _startName = start;
    _endName = end;
    _destination = dest;
    _routePoints = points;
    _targetDistance = distance;
    notifyListeners();

    final db = FuelDatabase.instance;
    await db.saveSetting('nav_start_name', start);
    await db.saveSetting('nav_end_name', end);
    await db.saveSetting('nav_dest_lat', dest.latitude.toString());
    await db.saveSetting('nav_dest_lng', dest.longitude.toString());
    await db.saveSetting('nav_target_dist', distance.toString());
  }

  double calculateRemainingRoadDistance(LatLng currentPos) {
    if (_routePoints.isEmpty || _destination == null) {
       // Fallback to straight line if points missing (e.g. after app restart)
       const distance = Distance();
       return distance.as(LengthUnit.Kilometer, currentPos, _destination!);
    }

    // Find the closest point index in the polyline
    int closestIdx = 0;
    double minDist = double.infinity;
    const distance = Distance();

    for (int i = 0; i < _routePoints.length; i++) {
        double d = distance.distance(currentPos, _routePoints[i]);
        if (d < minDist) {
          minDist = d;
          closestIdx = i;
        }
    }

    // Sum the remaining segments from the closest point to the end
    double remainingMeters = 0;
    // Add distance from current pos to the closest point
    remainingMeters += distance.distance(currentPos, _routePoints[closestIdx]);

    for (int i = closestIdx; i < _routePoints.length - 1; i++) {
      remainingMeters += distance.distance(_routePoints[i], _routePoints[i+1]);
    }

    return remainingMeters / 1000.0;
  }

  Future<void> clearDestination() async {
    _startName = null;
    _endName = null;
    _destination = null;
    _routePoints = [];
    notifyListeners();

    final db = FuelDatabase.instance;
    await db.saveSetting('nav_start_name', '');
    await db.saveSetting('nav_end_name', '');
    await db.saveSetting('nav_dest_lat', '');
    await db.saveSetting('nav_dest_lng', '');
    await db.saveSetting('nav_target_dist', '0');
  }
}
