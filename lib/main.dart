import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/location_service.dart';
import 'services/navigation_provider.dart';
import 'ui/theme.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/map_screen.dart';
import 'ui/screens/logs_screen.dart';
import 'ui/screens/settings_screen.dart';

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
        ChangeNotifierProvider<FuelProvider>(
          create: (_) => FuelProvider(),
        ),
        Provider<LocationService>(
          create: (_) => LocationService()..startTracking(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: const MotoMeterApp(),
    ),
  );
}

class MotoMeterApp extends StatelessWidget {
  const MotoMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Center( // Center the app on desktop
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500), // Android-like resolution limit
        child: MaterialApp(
          title: 'MotoMeter',
          debugShowCheckedModeBanner: false,
          theme: AmoledTheme.darkTheme,
          home: const MainNavigation(),
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MapScreen(),
    const LogsScreen(),
    const SettingsScreen(),
  ];

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
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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
