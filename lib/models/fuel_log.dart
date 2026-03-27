class FuelLog {
  final int? id;
  final DateTime date;
  final double? odometerReading; // Optional
  final double amountIdr;
  final double liters;
  final double pricePerLiter; // IDR per liter

  FuelLog({
    this.id,
    required this.date,
    this.odometerReading,
    required this.amountIdr,
    required this.liters,
    required this.pricePerLiter,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'odometer_reading': odometerReading,
      'amount_idr': amountIdr,
      'liters': liters,
      'price_per_liter': pricePerLiter,
    };
  }

  factory FuelLog.fromMap(Map<String, dynamic> map) {
    return FuelLog(
      id: map['id'],
      date: DateTime.parse(map['date']),
      odometerReading: map['odometer_reading'] != null ? (map['odometer_reading'] as num).toDouble() : null,
      amountIdr: (map['amount_idr'] as num).toDouble(),
      liters: (map['liters'] as num).toDouble(),
      pricePerLiter: (map['price_per_liter'] as num? ?? (map['amount_idr'] as num) / (map['liters'] as num)).toDouble(),
    );
  }
}
