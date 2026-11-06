import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeoLocationModel — represents a custom hidden spot with geofence radius
// ─────────────────────────────────────────────────────────────────────────────
class GeoLocationModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final Color color;
  final IconData icon;

  const GeoLocationModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.color,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// GeofenceEvent — recorded enter/exit event
// ─────────────────────────────────────────────────────────────────────────────
enum GeofenceEventType { enter, exit }

class GeofenceEvent {
  final String locationName;
  final GeofenceEventType type;
  final DateTime time;

  const GeofenceEvent({
    required this.locationName,
    required this.type,
    required this.time,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// LiangaLocations — 6 custom hidden spots in Lianga, Surigao del Sur
// These GPS coordinates represent local spots not marked on Google Maps.
// ─────────────────────────────────────────────────────────────────────────────
class LiangaLocations {
  /// Geographic centre latitude/longitude used as the initial map focus
  static const double centerLat = 8.6240;
  static const double centerLng = 126.0912;

  static const List<GeoLocationModel> all = [
    // 1 ── Hidden Cove Beach (undiscovered shoreline near barangay Buenavista)
    GeoLocationModel(
      id: 'loc_01',
      name: 'Hidden Cove Beach',
      category: '🏖️ Secret Spot',
      description:
          'A secluded sandy cove tucked behind mangrove trees along the Lianga Bay shore. '
          'Only visible during low tide. Locals use it for fishing at dawn.',
      latitude: 8.6187,
      longitude: 126.0882,
      radiusMeters: 60,
      color: Color(0xFF0288D1),
      icon: Icons.beach_access_rounded,
    ),

    // 2 ── Our House / Ancestral Home (Brgy. Mahaba)
    GeoLocationModel(
      id: 'loc_02',
      name: 'Ancestral Family Home',
      category: '🏠 Private Residence',
      description:
          'The family\'s ancestral bahay-na-bato style home built in the 1960s. '
          'Features a traditional bamboo slatted floor and an old mango tree in the backyard.',
      latitude: 8.6245,
      longitude: 126.0920,
      radiusMeters: 30,
      color: Color(0xFF5D4037),
      icon: Icons.home_rounded,
    ),

    // 3 ── Secret Mango Grove (undiscovered orchard, Brgy. Poblacion)
    GeoLocationModel(
      id: 'loc_03',
      name: 'Secret Mango Grove',
      category: '🌳 Hidden Nature',
      description:
          'A forgotten mango orchard overgrown with tall cogon grass. '
          'The old trees still bear fruit every summer. A favourite local hangout spot.',
      latitude: 8.6262,
      longitude: 126.0948,
      radiusMeters: 50,
      color: Color(0xFF388E3C),
      icon: Icons.park_rounded,
    ),

    // 4 ── Old Barangay Watching Post (hilltop lookout)
    GeoLocationModel(
      id: 'loc_04',
      name: 'Old Watchtower Hill',
      category: '👁️ Historic Spot',
      description:
          'Remnants of a World War II-era wooden watchtower on a small hill. '
          'Offers a panoramic view of Lianga Bay. Not visible on any map.',
      latitude: 8.6220,
      longitude: 126.0875,
      radiusMeters: 45,
      color: Color(0xFF795548),
      icon: Icons.visibility_rounded,
    ),

    // 5 ── Freshwater Spring (barangay water source)
    GeoLocationModel(
      id: 'loc_05',
      name: 'Barangay Spring Source',
      category: '💧 Natural Spring',
      description:
          'A natural freshwater spring used by residents for generations. '
          'The water is crystal-clear and cold year-round. Located deep in the bamboo forest.',
      latitude: 8.6278,
      longitude: 126.0905,
      radiusMeters: 35,
      color: Color(0xFF00838F),
      icon: Icons.water_rounded,
    ),

    // 6 ── Fishing Boat Landing (unmarked wharf)
    GeoLocationModel(
      id: 'loc_06',
      name: 'Fishermen\'s Landing',
      category: '⚓ Local Landmark',
      description:
          'An unmarked concrete ramp where local fishermen pull up their bancas every morning. '
          'The best place to buy fresh catch directly from the fishers.',
      latitude: 8.6198,
      longitude: 126.0898,
      radiusMeters: 40,
      color: Color(0xFF1565C0),
      icon: Icons.anchor_rounded,
    ),
  ];
}
