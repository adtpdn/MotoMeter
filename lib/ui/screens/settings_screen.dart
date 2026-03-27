import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/fuel_database.dart';
import '../../providers/fuel_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tankController = TextEditingController();
  final _ratioController = TextEditingController();
  final _gmtController = TextEditingController();
  final _odoController = TextEditingController();
  final _fuelController = TextEditingController();
  final _segmentController = TextEditingController();
  bool _enableOdo = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = FuelDatabase.instance;
    final tank = await db.getTankCapacity();
    final ratio = await db.getFuelRatio();
    final odo = await db.getLifetimeOdometer();
    final fuel = await db.getCurrentLiters();
    final segments = await db.getSetting('fuel_bar_segments') ?? '10';
    final odoEnabled = await db.getSetting('enable_odo_logging');
    final gmt = await db.getSetting('gmt_offset') ?? '8';
    
    setState(() {
      _tankController.text = tank.toString();
      _ratioController.text = ratio.toString();
      _odoController.text = odo.toStringAsFixed(1);
      _fuelController.text = fuel.toStringAsFixed(1);
      _segmentController.text = segments;
      _gmtController.text = gmt;
      _enableOdo = odoEnabled != 'false';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final db = FuelDatabase.instance;
    await db.saveSetting('tank_capacity', _tankController.text);
    await db.saveSetting('fuel_ratio', _ratioController.text);
    await db.saveSetting('odo_lifetime', _odoController.text);
    await db.saveSetting('current_liters', _fuelController.text);
    await db.saveSetting('fuel_bar_segments', _segmentController.text);
    await db.saveSetting('gmt_offset', _gmtController.text);
    await db.saveSetting('enable_odo_logging', _enableOdo.toString());
    
    if (mounted) {
      await context.read<FuelProvider>().refresh(); // Global Sync!
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved'), backgroundColor: Colors.blueAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('VEHICLE SETTINGS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('FUEL CONFIGURATION'),
            const SizedBox(height: 16),
            _buildTextField(_tankController, 'Tank Capacity (Liters)', Icons.local_gas_station),
            const SizedBox(height: 16),
            _buildTextField(_fuelController, 'Current Fuel Level (Liters)', Icons.gas_meter),
            const SizedBox(height: 16),
            _buildTextField(_ratioController, 'Fuel Ratio (KM / Liter)', Icons.show_chart),
            const SizedBox(height: 16),
            _buildTextField(_segmentController, 'Fuel Bar Segments (e.g. 10)', Icons.linear_scale),
            const SizedBox(height: 16),
            _buildTextField(_odoController, 'Current Total Odometer (KM)', Icons.speed),

    
            const SizedBox(height: 48),
            _buildSectionHeader('DATA LOGGING'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Enable Odometer Logging', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Ask for odometer reading during fuel entry', style: TextStyle(color: Colors.grey, fontSize: 11)),
              value: _enableOdo,
              activeColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _enableOdo = val),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('DISPLAY CONFIGURATION'),
            const SizedBox(height: 16),
            _buildTextField(_gmtController, 'GMT Offset (e.g. +7 or -3)', Icons.schedule),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SAVE SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2));
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF151515),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
