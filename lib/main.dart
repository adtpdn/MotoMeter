import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/location_service.dart';
import 'services/navigation_provider.dart';
import 'ui/theme.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/map_screen.dart';
import 'ui/screens/logs_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/fuel_entry_screen.dart';

import 'providers/fuel_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FuelProvider>(create: (_) => FuelProvider()),
        Provider<LocationService>(
          create: (_) => LocationService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<NavigationProvider>(create: (_) => NavigationProvider()),
      ],
      child: const MotoMeterApp(),
    ),
  );
}

final GlobalKey<MainNavigationState> mainNavKey = GlobalKey<MainNavigationState>();

class MotoMeterApp extends StatelessWidget {
  const MotoMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget app = MaterialApp(
      title: 'MotoMeter',
      debugShowCheckedModeBanner: false,
      theme: AmoledTheme.darkTheme,
      home: MainNavigation(key: mainNavKey),
    );

    if (kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))) {
      app = Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: app,
        ),
      );
    }

    return app;
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MapScreen(),
    const LogsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      try { WakelockPlus.enable(); } catch (_) {}
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFuelInitialization();
      context.read<LocationService>().startTracking();
    });
  }

  void switchToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _checkFuelInitialization() async {
    final fuelProvider = context.read<FuelProvider>();
    
    await fuelProvider.waitForReady();
    if (!mounted) return;

    // Step 1: Vehicle settings first
    if (!fuelProvider.isSettingsInitialized) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen(firstRun: true)),
      );
      if (result == true) {
        await fuelProvider.saveSetting('settings_initialized', 'true');
        await fuelProvider.refresh();
      }
      if (!mounted) return;
    }

    // Step 2: Initial fuel log
    if (!fuelProvider.isFuelInitialized) {
      switchToTab(2);
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FuelEntryScreen()),
      );
      if (result == true) {
        await fuelProvider.saveSetting('fuel_initialized', 'true');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Initial fuel tracked!'),
            backgroundColor: Colors.blueAccent,
          ));
          await fuelProvider.refresh();
          switchToTab(0); // Switch back to the Dash tab
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: switchToTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Dash'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.local_gas_station), label: 'Fuel'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
