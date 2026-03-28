import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/fuel_log.dart';

class FuelDatabase {
  static final FuelDatabase instance = FuelDatabase._init();
  static Database? _database;

  FuelDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('motometer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE fuel_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        odometer_reading REAL,
        amount_idr REAL NOT NULL,
        liters REAL NOT NULL,
        price_per_liter REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_name TEXT NOT NULL,
        end_name TEXT NOT NULL,
        dest_lat REAL NOT NULL,
        dest_lon REAL NOT NULL,
        timestamp TEXT NOT NULL,
        distance_km REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE bookmarks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        lat REAL,
        lon REAL
      )
    ''');

    await db.insert('settings', {'key': 'odo_lifetime', 'value': '0'});
    await db.insert('settings', {'key': 'tank_capacity', 'value': '7.0'});
    await db.insert('settings', {'key': 'fuel_ratio', 'value': '20.0'});
    await db.insert('settings', {'key': 'enable_odo_logging', 'value': 'false'});
    await db.insert('settings', {'key': 'current_liters', 'value': '0'});
    await db.insert('settings', {'key': 'gmt_offset', 'value': '8'});
    await db.insert('settings', {'key': 'fuel_bar_segments', 'value': '10'});
    await db.insert('settings', {'key': 'fuel_initialized', 'value': 'false'});
    await db.insert('settings', {'key': 'settings_initialized', 'value': 'false'});
    await db.insert('settings', {'key': 'clock_format', 'value': '24h'});
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE fuel_logs ADD COLUMN price_per_liter REAL DEFAULT 0');
      await db.execute('UPDATE fuel_logs SET price_per_liter = amount_idr / liters WHERE liters > 0');
      await db.execute('CREATE TABLE settings_new (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      final oldSettings = await db.query('settings');
      if (oldSettings.isNotEmpty) {
        final row = oldSettings.first;
        await db.insert('settings_new', {'key': 'odo_lifetime', 'value': (row['lifetime_odometer'] ?? 0).toString()});
        await db.insert('settings_new', {'key': 'tank_capacity', 'value': (row['tank_capacity'] ?? 7.0).toString()});
      }
      await db.execute('DROP TABLE settings');
      await db.execute('ALTER TABLE settings_new RENAME TO settings');
      await db.insert('settings', {'key': 'fuel_ratio', 'value': '20.0'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE trips (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_name TEXT NOT NULL,
          end_name TEXT NOT NULL,
          dest_lat REAL NOT NULL,
          dest_lon REAL NOT NULL,
          timestamp TEXT NOT NULL,
          distance_km REAL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.insert('settings', {'key': 'enable_odo_logging', 'value': 'false'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('settings', {'key': 'current_liters', 'value': '0'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      // Ensure ratio is 20 if default
      await db.insert('settings', {'key': 'fuel_ratio', 'value': '20.0'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('settings', {'key': 'tank_capacity', 'value': '7.0'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE bookmarks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          lat REAL,
          lon REAL
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.insert('settings', {'key': 'gmt_offset', 'value': '8'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('settings', {'key': 'fuel_bar_segments', 'value': '10'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('settings', {'key': 'fuel_initialized', 'value': 'false'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('settings', {'key': 'settings_initialized', 'value': 'false'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('settings', {'key': 'clock_format', 'value': '24h'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> wipeData() async {
    final db = await instance.database;
    await db.delete('fuel_logs');
    await db.delete('trips');
    await db.delete('bookmarks');
    await db.delete('settings');
    await db.insert('settings', {'key': 'odo_lifetime', 'value': '0'});
    await db.insert('settings', {'key': 'tank_capacity', 'value': '7.0'});
    await db.insert('settings', {'key': 'fuel_ratio', 'value': '20.0'});
    await db.insert('settings', {'key': 'enable_odo_logging', 'value': 'false'});
    await db.insert('settings', {'key': 'current_liters', 'value': '0'});
    await db.insert('settings', {'key': 'gmt_offset', 'value': '8'});
    await db.insert('settings', {'key': 'fuel_bar_segments', 'value': '10'});
    await db.insert('settings', {'key': 'fuel_initialized', 'value': 'false'});
    await db.insert('settings', {'key': 'settings_initialized', 'value': 'false'});
  }

  Future<String> exportData() async {
    final db = await instance.database;
    final logs = await db.query('fuel_logs');
    final trips = await db.query('trips');
    final bookmarks = await db.query('bookmarks');
    final settings = await db.query('settings');
    final data = {
      'fuel_logs': logs,
      'trips': trips,
      'bookmarks': bookmarks,
      'settings': settings,
    };
    return jsonEncode(data);
  }

  Future<void> importData(String jsonStr) async {
    final db = await instance.database;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    await db.delete('fuel_logs');
    await db.delete('trips');
    await db.delete('bookmarks');
    await db.delete('settings');

    for (final row in (data['fuel_logs'] as List? ?? [])) {
      await db.insert('fuel_logs', Map<String, dynamic>.from(row));
    }
    for (final row in (data['trips'] as List? ?? [])) {
      await db.insert('trips', Map<String, dynamic>.from(row));
    }
    for (final row in (data['bookmarks'] as List? ?? [])) {
      await db.insert('bookmarks', Map<String, dynamic>.from(row));
    }
    for (final row in (data['settings'] as List? ?? [])) {
      await db.insert('settings', Map<String, dynamic>.from(row), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<File> exportToFile() async {
    final jsonStr = await exportData();
    final dir = (await getDatabasesPath());
    final file = File('$dir/motometer_backup.sav');
    await file.writeAsString(jsonStr);
    return file;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  Future<int> insertFuelLog(FuelLog log) async {
    final db = await instance.database;
    final id = await db.insert('fuel_logs', log.toMap());
    
    // ADDITIVE: add liters to current tank level (capped to tank capacity)
    final current = await getCurrentLiters();
    final capacity = await getTankCapacity();
    await saveCurrentLiters((current + log.liters).clamp(0, capacity));
    
    if (log.odometerReading != null) {
      await saveSetting('odo_lifetime', log.odometerReading.toString());
    }
    
    return id;
  }

  Future<List<FuelLog>> getAllLogs() async {
    final db = await instance.database;
    final result = await db.query('fuel_logs', orderBy: 'date DESC');
    return result.map((json) => FuelLog.fromMap(json)).toList();
  }

  Future<int> updateFuelLog(FuelLog log) async {
    final db = await instance.database;

    // DELTA: adjust current_liters by the difference in liters
    final existing = await db.query('fuel_logs', where: 'id = ?', whereArgs: [log.id]);
    if (existing.isNotEmpty) {
      final oldLiters = (existing.first['liters'] as num).toDouble();
      final diff = log.liters - oldLiters;
      final current = await getCurrentLiters();
      final capacity = await getTankCapacity();
      await saveCurrentLiters((current + diff).clamp(0, capacity));
    }

    final res = await db.update('fuel_logs', log.toMap(), where: 'id = ?', whereArgs: [log.id]);
    return res;
  }

  Future<int> deleteFuelLog(int id) async {
    final db = await instance.database;
    // Subtract the liters of the deleted log from current_liters
    final existing = await db.query('fuel_logs', where: 'id = ?', whereArgs: [id]);
    if (existing.isNotEmpty) {
      final liters = (existing.first['liters'] as num).toDouble();
      final current = await getCurrentLiters();
      await saveCurrentLiters((current - liters).clamp(0, 9999));
    }
    return await db.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getLifetimeOdometer() async {
    final s = await getSetting('odo_lifetime');
    return double.tryParse(s ?? '0') ?? 0.0;
  }

  Future<double> getTankCapacity() async {
    final s = await getSetting('tank_capacity');
    return double.tryParse(s ?? '7.0') ?? 7.0;
  }

  Future<double> getFuelRatio() async {
    final s = await getSetting('fuel_ratio');
    return double.tryParse(s ?? '20.0') ?? 20.0;
  }

  Future<double> getCurrentLiters() async {
    final s = await getSetting('current_liters');
    return double.tryParse(s ?? '0.0') ?? 0.0;
  }

  Future<void> saveCurrentLiters(double liters) async {
    await saveSetting('current_liters', liters.toString());
  }

  Future<void> reduceFuel(double distanceKm) async {
    double current = await getCurrentLiters();
    double ratio = await getFuelRatio();
    if (ratio > 0) {
      double consumed = distanceKm / ratio;
      await saveCurrentLiters((current - consumed).clamp(0, 100));
    }
  }

  Future<Map<String, double>> getFuelStats() async {
    double fuelRatio = await getFuelRatio();
    double currentLiters = await getCurrentLiters();
    double tankCapacity = await getTankCapacity();
    
    double fuelPct = (currentLiters / tankCapacity).clamp(0, 1);

    return {
      'avg_consumption': fuelRatio,
      'cost_per_km': 0,
      'estimated_range': fuelRatio * currentLiters,
      'current_fuel_pct': fuelPct,
    };
  }

  // Bookmarks
  Future<int> insertBookmark(Map<String, dynamic> bookmark) async {
    final db = await instance.database;
    return await db.insert('bookmarks', bookmark);
  }

  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    final db = await instance.database;
    return await db.query('bookmarks', orderBy: 'id DESC');
  }

  Future<int> deleteBookmark(int id) async {
    final db = await instance.database;
    return await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // --- Trips ---
  Future<int> insertTrip(Map<String, dynamic> trip) async {
    final db = await instance.database;
    return await db.insert('trips', trip);
  }

  Future<List<Map<String, dynamic>>> getAllTrips() async {
    final db = await instance.database;
    return await db.query('trips', orderBy: 'timestamp DESC');
  }

  Future<int> deleteTrip(int id) async {
    final db = await instance.database;
    
    // Get distance before deleting to sync odo and fuel
    final result = await db.query('trips', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      double? dist = result.first['distance_km'] as double?;
      if (dist != null && dist > 0) {
        double currentTotal = await getLifetimeOdometer();
        double newTotal = (currentTotal - dist).clamp(0, double.infinity);
        await saveSetting('odo_lifetime', newTotal.toString());
        
        // Add fuel back (reverse reduceFuel)
        double currentLiters = await getCurrentLiters();
        double ratio = await getFuelRatio();
        if (ratio > 0) {
          await saveCurrentLiters(currentLiters + (dist / ratio));
        }
      }
    }
    
    return await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTrip(int id, Map<String, dynamic> trip) async {
    final db = await instance.database;
    
    // Adjust stats based on distance difference
    if (trip.containsKey('distance_km')) {
       final result = await db.query('trips', where: 'id = ?', whereArgs: [id]);
       if (result.isNotEmpty) {
          double oldDist = result.first['distance_km'] as double? ?? 0.0;
          double newDist = trip['distance_km'] as double? ?? 0.0;
          double diff = newDist - oldDist;
          
          if (diff != 0) {
            double currentOdo = await getLifetimeOdometer();
            double newTotal = (currentOdo + diff).clamp(0, double.infinity);
            await saveSetting('odo_lifetime', newTotal.toString());
            
            double currentLiters = await getCurrentLiters();
            double ratio = await getFuelRatio();
            if (ratio > 0) {
               await saveCurrentLiters(currentLiters - (diff / ratio));
            }
          }
       }
    }
    
    return await db.update('trips', trip, where: 'id = ?', whereArgs: [id]);
  }
}
