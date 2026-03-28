import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../database/fuel_database.dart';
import '../../providers/fuel_provider.dart';

// --- Vehicle Presets ---
const Map<String, Map<String, double>> kVehiclePresets = {
  'Custom': {},
  'Honda BeAT': {'tank': 4.2, 'ratio': 60.6},
  'Yamaha Aerox 155 (Connected)': {'tank': 5.5, 'ratio': 45.0},
  'Yamaha NMAX "Turbo" / Neo': {'tank': 7.1, 'ratio': 40.0},
  'Honda Vario 125': {'tank': 5.5, 'ratio': 51.7},
  'Yamaha YZF-R15 V2': {'tank': 12.0, 'ratio': 42.0},
  'Yamaha YZF-R15 V3': {'tank': 11.0, 'ratio': 45.0},
  'Yamaha YZF-R15 V4 / Connected': {'tank': 11.0, 'ratio': 48.0},
  'Suzuki GSX-R150': {'tank': 11.0, 'ratio': 38.5},
  'Honda CBR150R': {'tank': 12.0, 'ratio': 40.5},
  'Honda CBR250RR': {'tank': 14.5, 'ratio': 40.1},
  'Kawasaki Ninja 250 (Twin)': {'tank': 14.0, 'ratio': 25.0},
  'Yamaha YZF-R25': {'tank': 14.0, 'ratio': 30.0},
  'Yamaha XSR 155': {'tank': 10.0, 'ratio': 46.0},
  'Yamaha MT-15': {'tank': 10.4, 'ratio': 48.0},
  'Honda CB150R Streetfire': {'tank': 12.0, 'ratio': 40.5},
  'Yamaha MT-25': {'tank': 14.0, 'ratio': 22.5},
};

class SettingsScreen extends StatefulWidget {
  final bool firstRun;
  const SettingsScreen({super.key, this.firstRun = false});

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
  String _selectedPreset = 'Custom';
  String _clockFormat = '24h';

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
    final fmt = await db.getSetting('clock_format');
    if (mounted) setState(() => _clockFormat = fmt ?? '24h');
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
    await db.saveSetting('clock_format', _clockFormat);

    if (mounted) {
      await context.read<FuelProvider>().refresh();
      if (widget.firstRun) {
        Navigator.pop(context, true); // signal success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved'), backgroundColor: Colors.blueAccent),
        );
      }
    }
  }

  void _applyPreset(String name) {
    setState(() => _selectedPreset = name);
    final preset = kVehiclePresets[name];
    if (preset != null && preset.isNotEmpty) {
      _tankController.text = preset['tank'].toString();
      _ratioController.text = preset['ratio'].toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstRun ? 'VEHICLE SETUP' : 'VEHICLE SETTINGS'),
        leading: widget.firstRun ? null : const BackButton(),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.firstRun) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                  SizedBox(width: 12),
                  Expanded(child: Text('Configure your vehicle before tracking fuel.', style: TextStyle(color: Colors.grey, fontSize: 12))),
                ]),
              ),
              const SizedBox(height: 24),
            ],

            _buildSectionHeader('VEHICLE PRESET'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPreset,
                  dropdownColor: const Color(0xFF1A1A1A),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                  items: kVehiclePresets.keys.map((name) => DropdownMenuItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) { if (val != null) _applyPreset(val); },
                ),
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('FUEL CONFIGURATION'),
            const SizedBox(height: 16),
            _buildTextField(_tankController, 'Tank Capacity (Liters)', Icons.local_gas_station),
            const SizedBox(height: 16),
            _buildTextField(_ratioController, 'Fuel Ratio (KM / Liter)', Icons.show_chart),
            const SizedBox(height: 16),
            _buildTextField(_segmentController, 'Fuel Bar Segments (e.g. 10)', Icons.linear_scale),

            const SizedBox(height: 32),
            _buildSectionHeader('ODOMETER'),
            const SizedBox(height: 16),
            _buildTextField(_odoController, 'Current Total Odometer (KM)', Icons.speed),

            if (!widget.firstRun) ...[
              const SizedBox(height: 16),
              _buildTextField(_fuelController, 'Current Fuel Level (Liters)', Icons.gas_meter),

              const SizedBox(height: 32),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 12),
                  const Text('Clock Format', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const Spacer(),
                  ToggleButtons(
                    isSelected: [_clockFormat == '24h', _clockFormat == '12h'],
                    onPressed: (i) => setState(() => _clockFormat = i == 0 ? '24h' : '12h'),
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: Colors.blueAccent,
                    color: Colors.grey,
                    constraints: const BoxConstraints(minWidth: 52, minHeight: 36),
                    children: const [Text('24H', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), Text('12H', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))],
                  ),
                ],
              ),
            ],

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
                child: Text(
                  widget.firstRun ? 'CONFIRM & CONTINUE' : 'SAVE SETTINGS',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),

            if (!widget.firstRun) ...[
              const SizedBox(height: 32),
              _buildSectionHeader('DATA MANAGEMENT'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final file = await FuelDatabase.instance.exportToFile();
                      await Share.shareXFiles([XFile(file.path)], subject: 'MotoMeter Backup');
                    } catch (e) {
                      // Fallback to text share
                      final jsonStr = await FuelDatabase.instance.exportData();
                      await Share.share(jsonStr, subject: 'MotoMeter Backup');
                    }
                  },
                  icon: const Icon(Icons.download, color: Colors.blueAccent),
                  label: const Text('BACKUP DATA (.SAV)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF151515),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _importData,
                  icon: const Icon(Icons.upload, color: Colors.blueAccent),
                  label: const Text('IMPORT DATA (.SAV)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF151515),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmWipe,
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  label: const Text('WIPE ALL DATA', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF151515),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final content = await _readFile(path);
      // Quick validate it's our export format
      final parsed = jsonDecode(content);
      if (parsed is! Map || !parsed.containsKey('settings')) throw 'Invalid file format';

      await FuelDatabase.instance.importData(content);
      if (mounted) {
        await context.read<FuelProvider>().refresh();
        _loadSettings();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data imported successfully'), backgroundColor: Colors.blueAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<String> _readFile(String path) async {
    return await File(path).readAsString();
  }

  void _confirmWipe() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: const Text('Wipe All Data?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete ALL trips, logs, bookmarks, and reset settings to default.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await FuelDatabase.instance.wipeData();
              exit(0); // Forcibly close the app to require a clean cold start setup
            },
            child: const Text('WIPE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(
    title,
    style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
  );

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
