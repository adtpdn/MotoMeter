import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/fuel_database.dart';
import '../../models/fuel_log.dart';
import '../../providers/fuel_provider.dart';

class FuelEntryScreen extends StatefulWidget {
  final FuelLog? existingLog;
  const FuelEntryScreen({super.key, this.existingLog});

  @override
  State<FuelEntryScreen> createState() => _FuelEntryScreenState();
}

class _FuelEntryScreenState extends State<FuelEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerController = TextEditingController();
  final _amountController = TextEditingController();
  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  
  bool _showOdometer = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    if (widget.existingLog != null) {
      _odometerController.text = widget.existingLog!.odometerReading?.toString() ?? '';
      _amountController.text = widget.existingLog!.amountIdr.toString();
      _litersController.text = widget.existingLog!.liters.toString();
      _priceController.text = widget.existingLog!.pricePerLiter.toString();
    }
  }

  Future<void> _loadSettings() async {
    final enableOdo = await FuelDatabase.instance.getSetting('enable_odo_logging');
    if (mounted) {
      setState(() {
        _showOdometer = enableOdo != 'false';
        _isLoading = false;
      });
      if (widget.existingLog == null && _showOdometer) {
        final currentOdo = await FuelDatabase.instance.getLifetimeOdometer();
        _odometerController.text = currentOdo.toStringAsFixed(1);
      }
    }
  }

  void _calculateLiters() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    if (amount > 0 && price > 0) {
      _litersController.text = (amount / price).toStringAsFixed(2);
    }
  }

  void _calculatePrice() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final liters = double.tryParse(_litersController.text) ?? 0;
    if (amount > 0 && liters > 0) {
      _priceController.text = (amount / liters).toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingLog == null ? 'ADD FUEL LOG' : 'EDIT FUEL LOG'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showOdometer) ...[
                const Text('ODOMETER READING (KM)', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _odometerController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('e.g. 1250.5'),
                ),
                const SizedBox(height: 24),
              ],
              
              const Text('TOTAL AMOUNT (IDR)', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('e.g. 50000'),
                onChanged: (_) => _calculateLiters(),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PRICE / LITER', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Required'),
                          onChanged: (_) => _calculateLiters(),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LITERS', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _litersController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDecoration('Calculated'),
                          onChanged: (_) => _calculatePrice(),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final log = FuelLog(
                        id: widget.existingLog?.id,
                        date: widget.existingLog?.date ?? DateTime.now(),
                        odometerReading: double.tryParse(_odometerController.text),
                        amountIdr: double.parse(_amountController.text),
                        liters: double.parse(_litersController.text),
                        pricePerLiter: double.parse(_priceController.text),
                      );
                      
                      if (widget.existingLog == null) {
                        await FuelDatabase.instance.insertFuelLog(log);
                      } else {
                        await FuelDatabase.instance.updateFuelLog(log);
                      }
                      
                      if (context.mounted) {
                        // Refresh global provider state
                        final fuelProvider = Provider.of<FuelProvider>(context, listen: false);
                        if (log.odometerReading != null) {
                           fuelProvider.updateStatsImmediate(odo: log.odometerReading);
                        }
                        await fuelProvider.refresh();
                        
                        Navigator.pop(context, true);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(widget.existingLog == null ? 'SAVE LOG' : 'UPDATE LOG', 
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF151515),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
