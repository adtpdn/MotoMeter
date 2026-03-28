import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/location_service.dart';
import '../../services/navigation_provider.dart';
import '../../providers/fuel_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fuelProvider = context.watch<FuelProvider>();
    final locationService = Provider.of<LocationService>(context);
    final navProvider = Provider.of<NavigationProvider>(context);

    // Apply GMT offset from provider
    DateTime adjustedTime = _currentTime.toUtc().add(Duration(hours: fuelProvider.gmtOffset));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   StreamBuilder<double>(
                     stream: locationService.tripDistanceStream,
                     initialData: 0.0,
                     builder: (context, snapshot) {
                        double totalOdo = (fuelProvider.lifetimeOdo + (snapshot.data ?? 0.0)).clamp(0, double.infinity);
                        String odoStr = totalOdo.toStringAsFixed(0).padLeft(7, '0');
                        
                        // Find where the real digits start (skip leading zeros)
                        int firstNonZero = odoStr.indexOf(RegExp(r'[1-9]'));
                        if (firstNonZero == -1) firstNonZero = odoStr.length - 1; // All zeros case

                        return Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: odoStr.substring(0, firstNonZero), style: const TextStyle(color: Colors.white24)),
                              TextSpan(text: odoStr.substring(firstNonZero), style: const TextStyle(color: Colors.white)),
                              const TextSpan(text: ' KM', style: TextStyle(color: Colors.white24, fontSize: 10)),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        );
                     },
                   ),
                   Text(
                     DateFormat(fuelProvider.clockFormat == '12h' ? 'hh:mm:ss a' : 'HH:mm:ss').format(adjustedTime),
                     style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                   ),
                ],
              ),
              StreamBuilder<double>(
                stream: locationService.speedStream,
                initialData: 0.0,
                builder: (context, snapshot) {
                  String speedStr = snapshot.data!.toStringAsFixed(0).padLeft(3, '0');
                  int firstNonZero = speedStr.indexOf(RegExp(r'[1-9]'));
                  if (firstNonZero == -1) firstNonZero = speedStr.length - 1; // All zeros case

                  return Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: speedStr.substring(0, firstNonZero), style: const TextStyle(color: Colors.white24)),
                        TextSpan(text: speedStr.substring(firstNonZero), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, height: 1.1),
                  );
                },
              ),
              const Text('KM/H', style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
              
              const SizedBox(height: 30),

              _buildDigitalFuelBar(fuelProvider.fuelPct, fuelProvider.currentLiters, fuelProvider.estimatedRange, fuelProvider.fuelRatio, fuelProvider.fuelBarSegments),
              
              const SizedBox(height: 24),

              if (navProvider.hasActiveRoute) ...[
                _buildRouteInfo(
                  navProvider.startName ?? 'Current', 
                  navProvider.endName ?? 'Destination',
                  locationService.currentLocation != null 
                    ? navProvider.calculateRemainingRoadDistance(locationService.currentLocation!) 
                    : null
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      double actual = locationService.currentTripDistance;
                      double target = navProvider.targetDistance;
                      
                      double chosenDist = actual;
                      
                      if (target > 0 && actual < target - 1.0) {
                         final bool? useTarget = await showDialog<bool>(
                           context: context,
                           builder: (ctx) => AlertDialog(
                             backgroundColor: const Color(0xFF151515),
                             title: const Text('Complete Trip', style: TextStyle(color: Colors.white)),
                             content: const Text('You are ending the trip early. Which distance do you want to record?', style: TextStyle(color: Colors.grey)),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Actual (${actual.toStringAsFixed(1)} KM)', style: const TextStyle(color: Colors.blueAccent))),
                               TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Estimated (${target.toStringAsFixed(1)} KM)', style: const TextStyle(color: Colors.blueAccent))),
                             ]
                           )
                         );
                         if (useTarget == null) return;
                         chosenDist = useTarget ? target : actual;
                      } else {
                         if (actual == 0 && target > 0) chosenDist = target;
                      }

                      final stats = await locationService.saveCurrentOdometer(
                        navProvider.startName ?? 'Current', 
                        navProvider.endName ?? 'Destination',
                        navProvider.destination?.latitude ?? 0.0,
                        navProvider.destination?.longitude ?? 0.0,
                        chosenDist,
                      );
                      
                      // Immediate reactive update
                      fuelProvider.updateStatsImmediate(
                        odo: stats['new_odo'],
                        liters: stats['new_liters'],
                      );

                      await navProvider.clearDestination();
                      await fuelProvider.refresh(); // Formal database sync
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip Completed'), backgroundColor: Colors.blueAccent));
                      }
                    },
                    icon: const Icon(Icons.flag, color: Colors.white),
                    label: const Text('FINISH TRIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.15),
                      side: const BorderSide(color: Colors.blueAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfo(String from, String to, double? distance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.blueAccent, size: 8),
              const SizedBox(width: 10),
              Expanded(child: Text(from, style: const TextStyle(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis)),
              if (distance != null)
                SizedBox(
                  width: 80,
                  child: Text('${distance.toStringAsFixed(1)} KM', 
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
            ],
          ),
          Container(height: 10, width: 1, color: Colors.white24, margin: const EdgeInsets.only(left: 3.5)),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.redAccent, size: 12),
              const SizedBox(width: 10),
              Expanded(child: Text(to, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
              if (distance != null)
                const SizedBox(
                  width: 80,
                  child: Text('REMAINING', 
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey, fontSize: 8, letterSpacing: 0.5)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalFuelBar(double percentage, double liters, double range, double ratio, int segments) {
    int activeSegments = (percentage * segments).round();
    Color fuelColor = Color.lerp(Colors.redAccent, Colors.blueAccent, percentage) ?? Colors.blueAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Icon(Icons.local_gas_station, size: 12, color: fuelColor),
              const SizedBox(width: 8),
              Text(
                '${(percentage * 100).toInt()}% - ${liters.toStringAsFixed(1)}L - ${range.toStringAsFixed(0)}km',
                style: TextStyle(color: fuelColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(width: 4),
              Text('(1:${ratio.toInt()})', style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(segments, (index) {
            bool isActive = index < activeSegments;
            return Expanded(
              child: Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? fuelColor : Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override void dispose() { _clockTimer.cancel(); super.dispose(); }
}
