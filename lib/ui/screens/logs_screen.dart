import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../database/fuel_database.dart';
import '../../models/fuel_log.dart';
import '../../providers/fuel_provider.dart';
import 'fuel_entry_screen.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<FuelLog> _allLogs = [];
  List<FuelLog> _filteredLogs = [];
  double _totalSpent = 0;
  String _filter = 'All'; // 'All', 'Week', 'Month'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final logs = await FuelDatabase.instance.getAllLogs();
    setState(() {
      _allLogs = logs;
      _applyFilter();
    });
  }

  void _applyFilter() {
    DateTime now = DateTime.now();
    if (_filter == 'Week') {
      DateTime weekAgo = now.subtract(const Duration(days: 7));
      _filteredLogs = _allLogs.where((log) => log.date.isAfter(weekAgo)).toList();
    } else if (_filter == 'Month') {
      DateTime monthAgo = DateTime(now.year, now.month - 1, now.day);
      _filteredLogs = _allLogs.where((log) => log.date.isAfter(monthAgo)).toList();
    } else {
      _filteredLogs = _allLogs;
    }
    _totalSpent = _filteredLogs.fold(0, (sum, log) => sum + log.amountIdr);
  }

  Future<void> _deleteLog(int id) async {
    await FuelDatabase.instance.deleteFuelLog(id);
    if (mounted) {
      await context.read<FuelProvider>().refresh();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FUEL MANAGEMENT'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              setState(() {
                _filter = val;
                _applyFilter();
              });
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'All', child: Text('Show All')),
              const PopupMenuItem(value: 'Week', child: Text('This Week')),
              const PopupMenuItem(value: 'Month', child: Text('This Month')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF101010),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL ODOMETER', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                Text('${context.watch<FuelProvider>().lifetimeOdo.toStringAsFixed(1)} KM',
                    style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('EXPENDITURE (${_filter.toUpperCase()})', style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                Text('IDR ${NumberFormat("#,###").format(_totalSpent)}',
                    style: const TextStyle(fontSize: 28, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredLogs.length,
              separatorBuilder: (ctx, idx) => const Divider(color: Colors.white10),
              itemBuilder: (ctx, idx) {
                final log = _filteredLogs[idx];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1A1A1A),
                    child: Icon(Icons.local_gas_station, color: Colors.blueAccent, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('IDR ${NumberFormat("#,###").format(log.amountIdr)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('IDR ${NumberFormat("#,###").format(log.pricePerLiter)}/L', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  subtitle: Text(
                    '${log.liters.toStringAsFixed(2)}L • ${log.odometerReading != null ? "${log.odometerReading!.toStringAsFixed(0)} KM" : "No Odo"} • ${DateFormat('MMM dd').format(log.date)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white38),
                        onPressed: () async {
                           final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FuelEntryScreen(existingLog: log)),
                          );
                          if (result == true) {
                            if (mounted) await context.read<FuelProvider>().refresh();
                            _loadData();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent.withOpacity(0.5)),
                        onPressed: () => _deleteLog(log.id!),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FuelEntryScreen()),
          );
          if (result == true) {
            if (mounted) await context.read<FuelProvider>().refresh();
            _loadData();
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
