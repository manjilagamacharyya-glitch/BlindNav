import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/direction_step.dart';

class PlaceResult {
  final String name;
  final LatLng location;

  PlaceResult({required this.name, required this.location});
}

class MapsService {
  static const String googleMapsApiKey =
      'AIzaSyDAMJaEAFNbu8CMoRZCsOknUWpQpEq78oU';

  CameraPosition get initialCameraPosition =>
      const CameraPosition(target: LatLng(28.6139, 77.2090), zoom: 15.0);

  // Helper to bypass web CORS restrictions for the hackathon prototype
  Uri _getProxyUrl(Uri originalUrl) {
    return Uri.parse(
      'https://corsproxy.io/?url=${Uri.encodeComponent(originalUrl.toString())}',
    );
  }

  Future<List<String>> nearbyLandmarks(double lat, double lng) async {
    final url =
        Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
          'location': '$lat,$lng',
          'radius': '500',
          'type': 'point_of_interest',
          'key': googleMapsApiKey,
        });

    try {
      final response = await http.get(_getProxyUrl(url));
      if (response.statusCode != 200) {
        return [];
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null) {
        return [];
      }

      return results
          .map((item) => item['name'] as String?)
          .where((name) => name != null)
          .cast<String>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DirectionStep>> getDirections(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final url = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '$originLat,$originLng',
      'destination': '$destLat,$destLng',
      'mode': 'walking',
      'key': googleMapsApiKey,
    });

    try {
      final response = await http.get(_getProxyUrl(url));
      if (response.statusCode != 200) {
        return [];
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return [];
      }
      final legs = routes.first['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) {
        return [];
      }
      final steps = legs.first['steps'] as List<dynamic>?;
      if (steps == null) {
        return [];
      }

      return steps.map((step) {
        final instruction = step['html_instructions'] as String? ?? '';
        final distance = step['distance']?['text'] as String? ?? '';
        final duration = step['duration']?['text'] as String? ?? '';

        return DirectionStep(
          instruction: _stripHtml(instruction),
          distance: distance,
          duration: duration,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  Future<PlaceResult?> searchPlace(String query, double lat, double lng) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      {
        'query': query,
        'location': '$lat,$lng',
        'radius': '10000',
        'key': googleMapsApiKey,
      },
    );

    try {
      final response = await http.get(_getProxyUrl(url));
      if (response.statusCode != 200) {
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        return null;
      }
      final place = results.first as Map<String, dynamic>;
      final name = place['name'] as String?;
      final location = place['geometry']?['location'] as Map<String, dynamic>?;
      final latValue = location?['lat'] as num?;
      final lngValue = location?['lng'] as num?;

      if (name == null || latValue == null || lngValue == null) {
        return null;
      }

      return PlaceResult(
        name: name,
        location: LatLng(latValue.toDouble(), lngValue.toDouble()),
      );
    } catch (_) {
      return null;
    }
  }
}
