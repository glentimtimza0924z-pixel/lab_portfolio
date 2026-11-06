import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import 'models/geo_location_model.dart';

class GeofenceMapScreen extends StatefulWidget {
  const GeofenceMapScreen({super.key});

  @override
  State<GeofenceMapScreen> createState() => _GeofenceMapScreenState();
}

class _GeofenceMapScreenState extends State<GeofenceMapScreen>
    with TickerProviderStateMixin {
  // ── Map controller ──────────────────────────────────────────────────────────
  final MapController _mapController = MapController();

  // ── Custom locations in Lianga, Surigao del Sur ──────────────────────────
  final List<GeoLocationModel> _locations = LiangaLocations.all;

  // ── State ────────────────────────────────────────────────────────────────
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  GeoLocationModel? _selectedLocation;
  GeoLocationModel? _insideZone; // zone user is currently inside
  bool _isTracking = false;
  bool _locationPermissionGranted = false;
  bool _isLoadingLocation = false;
  final List<GeofenceEvent> _eventLog = [];

  // ── Animation for pulsing geofence ───────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  // ── Permission handling ──────────────────────────────────────────────────
  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Location services are disabled.', isError: true);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      _showSnack('Location permission denied.', isError: true);
      return;
    }
    setState(() => _locationPermissionGranted = true);
  }

  // ── Get one-shot location ─────────────────────────────────────────────────
  Future<void> _goToMyLocation() async {
    if (!_locationPermissionGranted) {
      await _checkPermissions();
      if (!_locationPermissionGranted) return;
    }
    setState(() => _isLoadingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });
      _mapController.move(
        LatLng(pos.latitude, pos.longitude),
        16,
      );
      _checkGeofences(pos);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      _showSnack('Could not get location: $e', isError: true);
    }
  }

  // ── Start/stop live tracking ──────────────────────────────────────────────
  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _positionStream?.cancel();
      setState(() {
        _isTracking = false;
        _insideZone = null;
      });
      _showSnack('Tracking stopped.');
      return;
    }
    if (!_locationPermissionGranted) {
      await _checkPermissions();
      if (!_locationPermissionGranted) return;
    }
    setState(() => _isTracking = true);
    _showSnack('Live geofence tracking started!');
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      setState(() => _currentPosition = pos);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
      _checkGeofences(pos);
    });
  }

  // ── Geofence logic ───────────────────────────────────────────────────────
  void _checkGeofences(Position pos) {
    for (final loc in _locations) {
      final dist = _distanceMeters(
        pos.latitude, pos.longitude,
        loc.latitude, loc.longitude,
      );
      final wasInside = _insideZone?.id == loc.id;
      final nowInside = dist <= loc.radiusMeters;

      if (nowInside && !wasInside) {
        setState(() => _insideZone = loc);
        _addEvent(GeofenceEvent(
          locationName: loc.name,
          type: GeofenceEventType.enter,
          time: DateTime.now(),
        ));
        _showSnack('📍 Entered: ${loc.name}', isError: false);
      } else if (!nowInside && wasInside) {
        setState(() => _insideZone = null);
        _addEvent(GeofenceEvent(
          locationName: loc.name,
          type: GeofenceEventType.exit,
          time: DateTime.now(),
        ));
        _showSnack('🚶 Exited: ${loc.name}', isError: false);
      }
    }
  }

  void _addEvent(GeofenceEvent event) {
    setState(() {
      _eventLog.insert(0, event);
      if (_eventLog.length > 20) _eventLog.removeLast();
    });
  }

  // ── Haversine distance (metres) ──────────────────────────────────────────
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.danger : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  String _formatDist(double m) =>
      m < 1000 ? '${m.toStringAsFixed(0)} m' : '${(m / 1000).toStringAsFixed(2)} km';

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Map – Lianga'),
        actions: [
          // Track toggle button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _isTracking ? AppTheme.danger : AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              onPressed: _toggleTracking,
              icon: Icon(
                _isTracking ? Icons.location_off : Icons.location_on,
                size: 16,
              ),
              label: Text(_isTracking ? 'Stop' : 'Track'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Active zone banner ──────────────────────────────────────────
          if (_insideZone != null)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (ctx, child) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _insideZone!.color.withValues(alpha: _pulseAnimation.value),
                child: Row(
                  children: [
                    Icon(_insideZone!.icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📍 You are inside: ${_insideZone!.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Map ─────────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(LiangaLocations.centerLat, LiangaLocations.centerLng),
                    initialZoom: 15.5,
                    onTap: (tapPos, point) => setState(() => _selectedLocation = null),
                  ),
                  children: [
                    // Tile layer (OpenStreetMap)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.master_compilation_app',
                      maxZoom: 19,
                    ),

                    // Geofence circles
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (ctx2, child) => CircleLayer(
                        circles: _locations.map((loc) {
                          final isActive = _insideZone?.id == loc.id;
                          final isSelected = _selectedLocation?.id == loc.id;
                          return CircleMarker(
                            point: LatLng(loc.latitude, loc.longitude),
                            radius: loc.radiusMeters,
                            useRadiusInMeter: true,
                            color: loc.color.withValues(
                              alpha: isActive
                                  ? _pulseAnimation.value * 0.6
                                  : (isSelected ? 0.35 : 0.18),
                            ),
                            borderColor: loc.color.withValues(
                              alpha: isActive ? 1.0 : 0.65,
                            ),
                            borderStrokeWidth: isActive ? 2.5 : 1.5,
                          );
                        }).toList(),
                      ),
                    ),

                    // Custom location markers
                    MarkerLayer(
                      markers: _locations.map((loc) {
                        final isActive = _insideZone?.id == loc.id;
                        final isSelected = _selectedLocation?.id == loc.id;
                        return Marker(
                          point: LatLng(loc.latitude, loc.longitude),
                          width: 44,
                          height: 54,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedLocation = loc),
                            child: Column(
                              children: [
                                Container(
                                  width: isSelected || isActive ? 40 : 36,
                                  height: isSelected || isActive ? 40 : 36,
                                  decoration: BoxDecoration(
                                    color: loc.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: isSelected || isActive ? 3 : 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: loc.color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: isActive ? 4 : 1,
                                      ),
                                    ],
                                  ),
                                  child: Icon(loc.icon, color: Colors.white, size: 18),
                                ),
                                CustomPaint(
                                  size: const Size(10, 8),
                                  painter: _MarkerTailPainter(loc.color),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // User location marker
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            width: 48,
                            height: 48,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (ctx3, child) => Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withValues(
                                      alpha: _pulseAnimation.value * 0.3),
                                  border: Border.all(
                                      color: Colors.blue, width: 2),
                                ),
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.blue,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Loading overlay
                if (_isLoadingLocation)
                  const Center(child: CircularProgressIndicator()),

                // OSM attribution
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Colors.black54),
                    ),
                  ),
                ),

                // FABs
                Positioned(
                  right: 12,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'locate',
                        tooltip: 'My Location',
                        onPressed: _goToMyLocation,
                        child: _isLoadingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'center',
                        tooltip: 'Center on Lianga',
                        onPressed: () => _mapController.move(
                            LatLng(LiangaLocations.centerLat, LiangaLocations.centerLng), 15.5),
                        child: const Icon(Icons.center_focus_strong_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Location detail / Info panel ────────────────────────────────
          if (_selectedLocation != null)
            _LocationDetailCard(
              location: _selectedLocation!,
              userPos: _currentPosition,
              distanceCalc: _distanceMeters,
              formatDist: _formatDist,
              insideZone: _insideZone,
              onClose: () => setState(() => _selectedLocation = null),
            ),

          // ── Locations list / event log tabs ──────────────────────────────
          if (_selectedLocation == null)
            _InfoPanel(
              locations: _locations,
              eventLog: _eventLog,
              insideZone: _insideZone,
              isDark: isDark,
              onLocationTap: (loc) {
                setState(() => _selectedLocation = loc);
                _mapController.move(
                    LatLng(loc.latitude, loc.longitude), 17);
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Panel (tabs: Locations | Event Log)
// ─────────────────────────────────────────────────────────────────────────────
class _InfoPanel extends StatefulWidget {
  final List<GeoLocationModel> locations;
  final List<GeofenceEvent> eventLog;
  final GeoLocationModel? insideZone;
  final bool isDark;
  final void Function(GeoLocationModel) onLocationTap;

  const _InfoPanel({
    required this.locations,
    required this.eventLog,
    required this.insideZone,
    required this.isDark,
    required this.onLocationTap,
  });

  @override
  State<_InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends State<_InfoPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Column(
        children: [
          TabBar(
            controller: _tab,
            tabs: [
              const Tab(text: 'Locations'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Event Log'),
                    if (widget.eventLog.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.info,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.eventLog.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Locations tab
                ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  itemCount: widget.locations.length,
                  separatorBuilder: (context2, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final loc = widget.locations[i];
                    final isActive = widget.insideZone?.id == loc.id;
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: loc.color,
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(loc.icon, color: Colors.white, size: 18),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              loc.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: loc.color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'INSIDE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${loc.category} • r=${loc.radiusMeters.toStringAsFixed(0)} m',
                        style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => widget.onLocationTap(loc),
                    );
                  },
                ),

                // Event Log tab
                widget.eventLog.isEmpty
                    ? Center(
                        child: Text(
                          'No geofence events yet.\nStart tracking to see events.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        itemCount: widget.eventLog.length,
                        itemBuilder: (context, i) {
                          final e = widget.eventLog[i];
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  e.type == GeofenceEventType.enter
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  size: 16,
                                  color: e.type == GeofenceEventType.enter
                                      ? AppTheme.success
                                      : AppTheme.danger,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${e.type == GeofenceEventType.enter ? "Entered" : "Exited"} ${e.locationName}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  _formatTime(e.time),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Location detail card (shown when marker tapped)
// ─────────────────────────────────────────────────────────────────────────────
class _LocationDetailCard extends StatelessWidget {
  final GeoLocationModel location;
  final Position? userPos;
  final double Function(double, double, double, double) distanceCalc;
  final String Function(double) formatDist;
  final GeoLocationModel? insideZone;
  final VoidCallback onClose;

  const _LocationDetailCard({
    required this.location,
    required this.userPos,
    required this.distanceCalc,
    required this.formatDist,
    required this.insideZone,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double? dist;
    if (userPos != null) {
      dist = distanceCalc(
        userPos!.latitude,
        userPos!.longitude,
        location.latitude,
        location.longitude,
      );
    }
    final isActive = insideZone?.id == location.id;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: location.color,
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: location.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(location.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            location.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: location.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '● INSIDE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      location.category,
                      style: TextStyle(
                        color: location.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            location.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          // Metadata row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: Icons.radio_button_unchecked,
                label: 'Radius: ${location.radiusMeters.toStringAsFixed(0)} m',
              ),
              _MetaChip(
                icon: Icons.location_pin,
                label:
                    '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
              ),
              if (dist != null)
                _MetaChip(
                  icon: Icons.social_distance_rounded,
                  label: 'Distance: ${formatDist(dist)}',
                  highlight: dist <= location.radiusMeters,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.success.withValues(alpha: 0.15)
            : (isDark ? AppTheme.darkCardBorder : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(6),
        border: highlight
            ? Border.all(color: AppTheme.success.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: highlight ? AppTheme.success : Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? AppTheme.success : Colors.grey[700],
              fontWeight:
                  highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom marker tail painter
// ─────────────────────────────────────────────────────────────────────────────
class _MarkerTailPainter extends CustomPainter {
  final Color color;
  _MarkerTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkerTailPainter old) => old.color != color;
}
