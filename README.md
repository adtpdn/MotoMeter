# MotoMeter 🏍️
**A High-Precision Digital Dashboard & Smart Fuel Manager for Motorcyclists.**

MotoMeter transforms your device into a professional "Pure Cockpit" instrument cluster. Built with Flutter, it prioritizes privacy (local-first storage) and extreme precision for long-distance riders and daily commuters alike.

![MotoMeter Cockpit](https://dummyimage.com/800x450/000/fff&text=MotoMeter+Pure+Cockpit)

## 🏁 Core Features

### 1. Dashboard (The Pure Cockpit)
- **Retro-Digital Odometer**: A high-precision 7-digit readout (`0005437 KM`) with zero-padding and live GPS increments.
- **Smart Fuel Bar**: Real-time remaining fuel in both **Percentage (%)**, **Volume (Liters)**, and **Range (KM)**.
- **High-Visibility Speedo**: Large 120pt digital KM/H display optimized for at-a-glance reading while riding.
- **Digital Instrument Clock**: Integrated clock with customizable GMT offsets to match any time zone.

### 2. Global State Synchronization
- **Single Source of Truth**: Powered by a central `FuelProvider`, ensuring your Odometer and Fuel levels are perfectly synchronized across the Dashboard, Fuel, and Settings screens.
- **Reactive Updates**: Zero-latency updates ensure that finishing a trip or adding a fuel log reflects instantly everywhere in the app.

### 3. Smart Navigation & Maps
- **Road-Accurate Distance**: Calculates "Remaining KM" using actual OSRM road polylines (not just straight lines).
- **Flexible Picking**: Tap-to-pick start and destination directly on the map, or use the integrated address search.
- **Bookmarks**: Save your favorite spots with a star icon for quick recall in your journey planning.
- **Trip Binding**: Lock in your destination to activate live remaining-distance tracking in the cockpit.

### 4. Trip History & Management (STOPS)
- **Automatic Logging**: Every "Finished" trip is formally recorded with names, coordinates, and exact distance.
- **Data Integrity**: Editing or deleting past trips automatically RECONCILES your global odometer and fuel stats, keeping your lifetime records accurate.

### 5. Fuel Analytics (FUEL)
- **Odometer-Synced Logs**: Add fuel logs including price, amount, and current odometer reading.
- **Consumption Tracking**: Tracks your vehicle's efficiency ratio (KM/Liter) to provide accurate range estimates.

### 6. Advanced Settings
- **Calibration Controls**: Manually override Tank Capacity, Current Fuel Level, and Lifetime Odometer for absolute accuracy.
- **GMT Offset**: Configure the dashboard clock to any global timezone.
- **Privacy First**: All data is stored locally in an encrypted SQLite database. No accounts, no cloud, no tracking.

## 🛠️ Technical Implementation
- **Framework**: [Flutter](https://flutter.dev) for cross-platform performance.
- **State Management**: [Provider](https://pub.dev/packages/provider) for reactive global synchronization.
- **Database**: [Sqflite](https://pub.dev/packages/sqflite) (SQLite) with FFI support for Windows deployment.
- **API Integration**: [OSRM API](http://project-osrm.org/) for real-time road-aligned routing.
- **Mapping**: [Flutter Map](https://pub.dev/packages/flutter_map) with custom dark-mode tile layers.

## 🚀 Getting Started
1. Clone the repository.
2. Run `flutter pub get`.
3. Launch on Android, iOS, or Windows for a mobile-native cockpit experience.

---
**Ride safe. Track smart.**
