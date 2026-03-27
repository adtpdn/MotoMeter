import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/fuel_database.dart';

class FuelProvider extends ChangeNotifier {
  double _lifetimeOdo = 0;
  double _currentLiters = 0;
  double _fuelPct = 0;
  double _estimatedRange = 0;
  double _fuelRatio = 20;
  double _tankCapacity = 7;
  int _fuelBarSegments = 10;
  int _gmtOffset = 8;
  bool _isFuelInitialized = false;

  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> waitForReady() => _readyCompleter.future;

  double get lifetimeOdo => _lifetimeOdo;
  double get currentLiters => _currentLiters;
  double get fuelPct => _fuelPct;
  double get estimatedRange => _estimatedRange;
  double get fuelRatio => _fuelRatio;
  double get tankCapacity => _tankCapacity;
  int get fuelBarSegments => _fuelBarSegments;
  int get gmtOffset => _gmtOffset;
  bool get isFuelInitialized => _isFuelInitialized;

  // Typography logic
  TextStyle get mainFont => GoogleFonts.shareTechMono();
  TextStyle get instrumentFont => GoogleFonts.shareTechMono();

  FuelProvider() {
    refresh();
  }

  // Reactive updates for immediate UI feedback
  void updateStatsImmediate({double? odo, double? liters}) {
    if (odo != null) _lifetimeOdo = odo;
    if (liters != null) {
      _currentLiters = liters;
      _fuelPct = (_currentLiters / _tankCapacity).clamp(0, 1);
      _estimatedRange = _fuelRatio * _currentLiters;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final db = FuelDatabase.instance;
      _lifetimeOdo = await db.getLifetimeOdometer();
      final stats = await db.getFuelStats();
      _currentLiters = await db.getCurrentLiters();
      _fuelRatio = await db.getFuelRatio();
      _tankCapacity = await db.getTankCapacity();
      _fuelPct = stats['current_fuel_pct'] ?? 0;
      _estimatedRange = stats['estimated_range'] ?? 0;
      
      final gmt = await db.getSetting('gmt_offset');
      _gmtOffset = int.tryParse(gmt ?? '8') ?? 8;

      final segments = await db.getSetting('fuel_bar_segments');
      _fuelBarSegments = int.tryParse(segments ?? '10') ?? 10;
      
      final isInit = await db.getSetting('fuel_initialized');
      _isFuelInitialized = isInit == 'true';

      debugPrint('FuelProvider Refreshed: ODO=$_lifetimeOdo');
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      notifyListeners();
    } catch (e) {
      debugPrint('FuelProvider Refresh Error: $e');
    }
  }

  // Helper to save and refresh
  Future<void> saveSetting(String key, String value) async {
    await FuelDatabase.instance.saveSetting(key, value);
    await refresh();
  }
}
