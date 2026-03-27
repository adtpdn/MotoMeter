import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    // Switching to OSRM for more reliable road-aligned routing
    final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['routes'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;
        return coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
      }
    } catch (e) {
      print('Route error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getAddressSuggestions(String query) async {
    final url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5';
    
    try {
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'MotoMeter'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) => {
          'display_name': item['display_name'],
          'lat': double.parse(item['lat'] as String),
          'lon': double.parse(item['lon'] as String),
        }).toList();
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return [];
  }

  Future<LatLng?> resolveGoogleMapsUrl(String url) async {
    try {
      String currentUrl = url;
      final client = http.Client();
      
      // Manually follow up to 10 redirects to ensure we get the final URL with coordinates
      for (int i = 0; i < 10; i++) {
        final request = http.Request('GET', Uri.parse(currentUrl))..followRedirects = false;
        request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
        
        final streamedResponse = await client.send(request);
        if (streamedResponse.statusCode >= 300 && streamedResponse.statusCode < 400) {
          final location = streamedResponse.headers['location'];
          if (location != null) {
            currentUrl = location.startsWith('http') ? location : Uri.parse(currentUrl).resolve(location).toString();
            continue;
          }
        }
        currentUrl = streamedResponse.request?.url.toString() ?? currentUrl;
        break;
      }

      final finalUrl = currentUrl;
      
      // Patterns: @-8.631,115.195 or 3d-8.631!4d115.195 or ll=-8.631,115.195
      final regexAt = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      final regex3d = RegExp(r'3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
      final regexQ = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
      final regexLL = RegExp(r'll=(-?\d+\.\d+),(-?\d+\.\d+)');

      var match = regexAt.firstMatch(finalUrl);
      match ??= regex3d.firstMatch(finalUrl);
      match ??= regexQ.firstMatch(finalUrl);
      match ??= regexLL.firstMatch(finalUrl);

      if (match != null) {
        return LatLng(double.parse(match.group(1)!), double.parse(match.group(2)!));
      }
    } catch (e) {
      print('URL resolution error: $e');
    }
    return null;
  }
}
