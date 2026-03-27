import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/location_service.dart';
import '../../services/route_service.dart';
import '../../services/navigation_provider.dart';
import '../../database/fuel_database.dart';
import '../../providers/fuel_provider.dart';
import '../../main.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RouteService _routeService = RouteService();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;
  
  List<LatLng> _routePoints = [];
  LatLng? _manualStart;
  LatLng? _destination;
  LatLng _userPos = const LatLng(-6.2000, 106.8166);
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _tripHistory = [];
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = false;
  bool _showPanel = true;
  bool _pickModeEnabled = false; 
  bool _activePickIsStart = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initUserLocation();
    _loadData();
  }

  Future<void> _initUserLocation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final pos = await locationService.getCurrentPosition();
    if (pos != null) {
      if (mounted) {
        setState(() => _userPos = LatLng(pos.latitude, pos.longitude));
        _mapController.move(_userPos, 15);
      }
    }
  }

  Future<void> _loadData() async {
    final db = FuelDatabase.instance;
    final history = await db.getAllTrips();
    final bms = await db.getAllBookmarks();
    if (mounted) {
      setState(() {
        _tripHistory = history;
        _bookmarks = bms;
      });
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    if (start.latitude == end.latitude && start.longitude == end.longitude) {
      setState(() {
        _routePoints = [start];
        _isLoading = false;
      });
      _mapController.move(start, 15);
      return;
    }

    setState(() => _isLoading = true);
    final route = await _routeService.getRoute(start, end);
    if (mounted) {
      setState(() {
        _routePoints = route;
        _isLoading = false;
      });
      if (_routePoints.isNotEmpty) {
        if (_routePoints.length > 1) {
          _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(_routePoints), padding: const EdgeInsets.all(70)));
        } else {
          _mapController.move(_routePoints.first, 15);
        }
      }
    }
  }

  double _getTripDistance() {
    final distance = const Distance();
    if (_routePoints.isEmpty) {
      if (_destination != null) {
        LatLng start = _manualStart ?? _userPos;
        return distance.as(LengthUnit.Kilometer, start, _destination!);
      }
      return 0.0;
    }
    double totalMeters = 0.0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
        totalMeters += distance.distance(_routePoints[i], _routePoints[i + 1]);
    }
    return totalMeters / 1000.0;
  }

  Future<void> _handleSearchInput(String val, bool isStart) async {
    _activePickIsStart = isStart;
    
    if (val.startsWith('http') && (val.contains('maps') || val.contains('goo.gl'))) {
       setState(() {
         _isLoading = true;
         if (isStart) _startController.text = 'Resolving Link...';
         else _destController.text = 'Resolving Link...';
         _suggestions = [];
       });
       
       final coords = await _routeService.resolveGoogleMapsUrl(val);
       if (mounted) {
         setState(() {
           _isLoading = false;
           if (coords != null) {
             final coordString = '${coords.latitude.toStringAsFixed(6)}, ${coords.longitude.toStringAsFixed(6)}';
             if (isStart) {
                _manualStart = coords;
                _startController.text = coordString;
             } else {
                _destination = coords;
                _destController.text = coordString;
             }
             _mapController.move(coords, 14); 
             if (_destination != null) _fetchRoute(_manualStart ?? _userPos, _destination!);
           } else {
             if (isStart) _startController.text = 'Failed to resolve link';
             else _destController.text = 'Failed to resolve link';
           }
         });
       }
       return;
    }

    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      if (val.length > 2) {
        final sug = await _routeService.getAddressSuggestions(val);
        if (mounted) setState(() => _suggestions = sug);
      }
    });
  }

  Future<void> _toggleBookmark(bool isStart) async {
    final controller = isStart ? _startController : _destController;
    final pos = isStart ? (_manualStart ?? _userPos) : _destination;
    if (pos == null) return;

    final nameController = TextEditingController(text: controller.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: const Text('Save Bookmark', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FuelDatabase.instance.insertBookmark({
                'name': nameController.text.isEmpty ? 'Saved Place' : nameController.text,
                'lat': pos.latitude,
                'lon': pos.longitude,
              });
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPos, 
              initialZoom: 13,
              backgroundColor: Colors.black,
              onTap: (_, p) {
                if (_pickModeEnabled) {
                  setState(() {
                    _suggestions = [];
                    if (_activePickIsStart) {
                      _manualStart = p;
                      _startController.text = '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
                    } else {
                      _destination = p;
                      _destController.text = '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
                    }
                    if (_destination != null) _fetchRoute(_manualStart ?? _userPos, _destination!);
                  });
                }
                FocusScope.of(context).unfocus();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.motometer.app',
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(points: _routePoints, color: Colors.blueAccent.withOpacity(0.8), strokeWidth: 5, borderColor: Colors.white24, borderStrokeWidth: 1)
                  else if (_destination != null)
                    Polyline(points: [_manualStart ?? _userPos, _destination!], color: Colors.blueAccent.withOpacity(0.5), strokeWidth: 3, isDotted: true),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_destination != null)
                    Marker(point: _destination!, child: const Icon(Icons.location_on, color: Colors.redAccent, size: 30)),
                  if (_manualStart != null)
                    Marker(point: _manualStart!, child: const Icon(Icons.trip_origin, color: Colors.blueAccent, size: 30)),
                  Marker(point: _userPos, child: Container(decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                ],
              ),
            ],
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   _buildSearchField(controller: _startController, hint: 'From', isStart: true),
                  const SizedBox(height: 8),
                   _buildSearchField(controller: _destController, hint: 'Destination', isStart: false),
                  if (_suggestions.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                        child: ListView.separated(
                          shrinkWrap: true, itemCount: _suggestions.length > 3 ? 3 : _suggestions.length, 
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (ctx, idx) {
                            final s = _suggestions[idx];
                            return ListTile(
                              title: Text(s['display_name'], style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1),
                              onTap: () {
                                final p = LatLng(s['lat'], s['lon']);
                                if (_activePickIsStart) { setState(() { _manualStart = p; _startController.text = s['display_name']; _suggestions = []; }); }
                                else { setState(() { _destination = p; _destController.text = s['display_name']; _suggestions = []; }); }
                                if (_destination != null) _fetchRoute(_manualStart ?? _userPos, _destination!);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  if (_destination != null && !navProvider.hasActiveRoute && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                            child: Text('${_getTripDistance().toStringAsFixed(1)} KM', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () { 
                              navProvider.bindDestination(
                                _startController.text.isEmpty ? 'Current Position' : _startController.text, 
                                _destController.text, 
                                _destination!, 
                                _getTripDistance(),
                                _routePoints
                              );
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bind Successfully, check Dash section'), backgroundColor: Colors.blueAccent));
                              mainNavKey.currentState?.switchToTab(0);
                            },
                            icon: const Icon(Icons.check_circle, size: 18), label: const Text('BIND'), 
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          ),
                        ],
                      ),
                    ),
                  if (_isLoading) const Padding(padding: EdgeInsets.only(top: 12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
                ],
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel()),
          
          // Action Buttons
          Positioned(
            right: 16, bottom: _showPanel ? 260 : 80,
            child: Column(
              children: [
                _buildActionButton(
                  icon: Icons.touch_app, 
                  color: _pickModeEnabled ? Colors.blueAccent : Colors.grey[900]!,
                  onPressed: () => setState(() => _pickModeEnabled = !_pickModeEnabled),
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.my_location, color: Colors.blueAccent,
                  onPressed: () {
                    setState(() {
                      _manualStart = null;
                      _startController.text = '${_userPos.latitude.toStringAsFixed(5)}, ${_userPos.longitude.toStringAsFixed(5)}';
                      _pickModeEnabled = false;
                    });
                    _mapController.move(_userPos, 15);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return FloatingActionButton.small(
      heroTag: null, onPressed: onPressed, backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildSearchField({required TextEditingController controller, required String hint, required bool isStart}) {
    bool isFocused = _activePickIsStart == isStart && _pickModeEnabled;
    return Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515), borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: isFocused ? Colors.blueAccent : Colors.white10),
      ),
      child: Center(
        child: TextField(
          controller: controller, textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onTap: () => setState(() => _activePickIsStart = isStart),
          decoration: InputDecoration(
            isCollapsed: true,
            icon: Icon(isStart ? Icons.trip_origin : Icons.location_on, color: isStart ? Colors.blueAccent : Colors.redAccent, size: 18),
            hintText: hint, hintStyle: const TextStyle(color: Colors.grey), border: InputBorder.none,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.star_border, size: 18, color: Colors.white38), onPressed: () => _toggleBookmark(isStart)),
                if (controller.text.isNotEmpty) 
                  IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() { controller.clear(); if(isStart) _manualStart = null; else _destination = null; _routePoints = []; })),
              ],
            ),
          ),
          onChanged: (val) => _handleSearchInput(val, isStart),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), height: _showPanel ? 280 : 85,
      decoration: const BoxDecoration(color: Color(0xFF101010), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showPanel = !_showPanel),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.transparent,
              child: Column(children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 8)]),
            ),
          ),
          TabBar(
            controller: _tabController, indicatorColor: Colors.blueAccent, labelColor: Colors.white, unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
            tabs: const [Tab(text: 'STOPS'), Tab(text: 'BOOKMARKS')],
          ),
          if (_showPanel)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildHistoryList(), _buildBookmarkList()],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_tripHistory.isEmpty) return const Center(child: Text('No history', style: TextStyle(color: Colors.grey)));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _tripHistory.length, separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (ctx, idx) {
        final trip = _tripHistory[idx];
        double dist = (trip['distance_km'] as num?)?.toDouble() ?? 0.0;
        return ListTile(
          contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history, color: Colors.white24, size: 18),
          title: Text(trip['end_name'], style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1),
          subtitle: Text('${DateFormat('MMM dd, HH:mm').format(DateTime.parse(trip['timestamp']))} • ${dist.toStringAsFixed(1)} KM', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit_note, color: Colors.white38, size: 18), onPressed: () => _showEditTripDialog(trip)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _confirmDeleteTrip(trip['id'])),
              const SizedBox(width: 4),
              IconButton(icon: const Icon(Icons.directions, color: Colors.blueAccent, size: 18), onPressed: () => _fetchRoute(_userPos, LatLng(trip['dest_lat'], trip['dest_lon']))),
            ],
          ),
        );
      },
    );
  }

  void _showEditTripDialog(Map<String, dynamic> trip) {
    final controller = TextEditingController(text: trip['distance_km'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: const Text('Edit Trip Distance', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Updating the distance will automatically adjust your Odometer and Fuel stats.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 16),
            TextField(
              controller: controller, keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Distance (KM)', labelStyle: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(onPressed: () async {
            double? newDist = double.tryParse(controller.text);
            if (newDist != null) {
              await FuelDatabase.instance.updateTrip(trip['id'], {'distance_km': newDist});
              if (mounted) {
                await context.read<FuelProvider>().refresh(); // Global Sync!
                _loadData(); 
                Navigator.pop(ctx);
              }
            }
          }, child: const Text('SAVE', style: TextStyle(color: Colors.blueAccent))),
        ],
      ),
    );
  }

  void _confirmDeleteTrip(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: const Text('Delete Trip?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Deleting this trip will also REVERT the added Odometer and consumed Fuel from your totals.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(onPressed: () async {
            await FuelDatabase.instance.deleteTrip(id);
            if (mounted) {
              await context.read<FuelProvider>().refresh(); // Global Sync!
              _loadData();
              Navigator.pop(ctx);
            }
          }, child: const Text('DELETE', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Widget _buildBookmarkList() {
    if (_bookmarks.isEmpty) return const Center(child: Text('No bookmarks', style: TextStyle(color: Colors.grey)));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _bookmarks.length, separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (ctx, idx) {
        final bm = _bookmarks[idx];
        return ListTile(
          contentPadding: EdgeInsets.zero, leading: const Icon(Icons.star, color: Colors.amber, size: 18),
          title: Text(bm['name'], style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1),
          onTap: () {
            final p = LatLng(bm['lat'], bm['lon']);
            setState(() {
              if (_activePickIsStart) { _manualStart = p; _startController.text = bm['name']; }
              else { _destination = p; _destController.text = bm['name']; }
            });
            if (_destination != null) _fetchRoute(_manualStart ?? _userPos, _destination!);
          },
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16), onPressed: () async {
            await FuelDatabase.instance.deleteBookmark(bm['id']);
            _loadData();
          }),
        );
      },
    );
  }

  @override void dispose() { _tabController.dispose(); _debounce?.cancel(); _startController.dispose(); _destController.dispose(); super.dispose(); }
}
