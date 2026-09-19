import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/location_service.dart';
import '../../../data/models/camp.dart';
import '../../../data/repositories/camp_repository.dart';
import '../data/emergency_repository.dart';
import '../data/models/disaster_zone.dart';
import '../data/models/emergency_alert.dart';
import '../data/spring_boot_emergency_repository.dart';
import '../domain/nearest_camp.dart';
import '../domain/safety_calculator.dart';
import '../domain/safety_zone.dart';
import '../../incidents/data/incident_repository.dart';
import '../../incidents/data/models/incident.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key, this.repository, this.initialDisaster});

  final EmergencyRepository? repository;
  final DisasterZone? initialDisaster;

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  final _mapController = MapController();
  late final LocationService _locationService = LocationService();
  final _campRepository = CampRepository();
  late final IncidentRepository _incidentRepository;
  late final EmergencyRepository _emergencyRepository =
      widget.repository ?? SpringBootEmergencyRepository();

  LocationResult? _location;
  List<DisasterZone> _disasters = [];
  List<Camp> _camps = [];
  bool _loading = true;
  String? _locationMessage;
  List<Incident> _deduplicatedIncidents = const [];
  String? _selectedIncidentId;
  LatLng? _incidentCenter;
  double? _incidentGreenRadiusKm;

  bool get _isIncidentSpecific => widget.initialDisaster != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDisaster;
    debugPrint('[SAFETY-MAP-CONSTRUCTOR]'
        ' initialDisasterExists=${d != null}'
        ' incidentId=${d?.incidentId}'
        ' incidentName=${d?.title}'
        ' latitude=${d?.latitude}'
        ' longitude=${d?.longitude}'
        ' severity=${d?.severity}'
        ' redZoneKm=${d?.redZoneKm}'
        ' yellowZoneKm=${d?.yellowZoneKm}'
        ' greenZoneKm=${d?.greenZoneKm}');
    final authService = context.read<AppState>().authService;
    _incidentRepository = IncidentRepository(authService: authService);
    _loadSafetyData();
  }

  Future<void> _loadSafetyData() async {
    setState(() => _loading = true);
    final cachedCamps = context.read<AppState>().syncService.camps;

    if (!_isIncidentSpecific) {
      try {
        final incidents = await _incidentRepository.getActiveSearchable();
        final uniqueMap = <String, Incident>{};
        for (final incident in incidents) {
          if (incident.id.isNotEmpty) {
            uniqueMap[incident.id] = incident;
          }
        }
        _deduplicatedIncidents = uniqueMap.values.toList();
        if (_selectedIncidentId != null &&
            !_deduplicatedIncidents.any((i) => i.id == _selectedIncidentId)) {
          _selectedIncidentId = null;
        }
        if (_selectedIncidentId == null && _deduplicatedIncidents.isNotEmpty) {
          _selectedIncidentId = _deduplicatedIncidents.first.id;
        }
      } catch (_) {
        _deduplicatedIncidents = const [];
      }
    }

    List<DisasterZone> zones;
    try {
      zones = (await _emergencyRepository.getActiveDisasterZones())
          .where(_isValidZone)
          .where((zone) {
        if (_isIncidentSpecific) {
          return zone.incidentId == widget.initialDisaster?.incidentId ||
              zone.id == widget.initialDisaster?.id;
        }
        return _selectedIncidentId == null ||
            zone.incidentId == _selectedIncidentId;
      }).toList();
    } catch (_) {
      zones = [];
    }

    List<Camp> camps;
    try {
      final remoteCamps = await _campRepository.getActiveCamps();
      camps = remoteCamps.isNotEmpty
          ? remoteCamps
          : await cachedCamps.getActive();
    } catch (_) {
      camps = await cachedCamps.getActive();
    }

    final permission = await _locationService.checkAndRequestPermission();
    LocationResult? location;
    if (permission == LocationPermissionStatus.granted) {
      location = await _locationService.getCurrentLocation();
    }
    if (!mounted) return;

    final initialDisaster = widget.initialDisaster;
    setState(() {
      _location = location;

      if (initialDisaster != null) {
        _incidentCenter = LatLng(initialDisaster.latitude, initialDisaster.longitude);
        _incidentGreenRadiusKm = initialDisaster.greenZoneKm;
        _disasters = [
          if (_isValidZone(initialDisaster)) initialDisaster,
          ...zones.where((zone) => zone.id != initialDisaster.id),
        ];
      } else if (!_isIncidentSpecific && _selectedIncidentId != null) {
        final selectedIncident = _deduplicatedIncidents
            .where((i) => i.id == _selectedIncidentId)
            .firstOrNull;
        if (selectedIncident != null &&
            selectedIncident.latitude != null &&
            selectedIncident.longitude != null) {
          final radii = _zoneRadiiForSeverity(selectedIncident.severity);
          final redKm = selectedIncident.redZoneKm ?? radii.$1;
          final yellowKm = selectedIncident.yellowZoneKm ?? radii.$2;
          final greenKm = selectedIncident.greenZoneKm ?? radii.$3;
          _incidentCenter = LatLng(
              selectedIncident.latitude!, selectedIncident.longitude!);
          _incidentGreenRadiusKm = greenKm;
          final incidentZone = DisasterZone(
            id: 'incident-${selectedIncident.id}',
            incidentId: selectedIncident.id,
            disasterType: selectedIncident.severity ?? 'UNKNOWN',
            latitude: selectedIncident.latitude!,
            longitude: selectedIncident.longitude!,
            radiusKm: greenKm,
            severity: _parseSeverity(selectedIncident.severity),
            title: selectedIncident.name,
            active: true,
            redZoneKm: redKm,
            yellowZoneKm: yellowKm,
            greenZoneKm: greenKm,
          );
          _disasters = [
            if (_isValidZone(incidentZone)) incidentZone,
            ...zones.where((z) => z.incidentId != selectedIncident.id),
          ];
          debugPrint('[SAFETY-MAP-INCIDENT-SELECT]'
              ' selectedIncidentId=${selectedIncident.id}'
              ' selectedIncidentName=${selectedIncident.name}'
              ' latitude=${selectedIncident.latitude}'
              ' longitude=${selectedIncident.longitude}'
              ' severity=${selectedIncident.severity}'
              ' redZoneKm=$redKm'
              ' yellowZoneKm=$yellowKm'
              ' greenZoneKm=$greenKm');
        } else {
          _incidentCenter = null;
          _incidentGreenRadiusKm = null;
          _disasters = zones;
        }
      } else {
        _incidentCenter = null;
        _incidentGreenRadiusKm = null;
        _disasters = zones;
      }

      _camps = camps;
      _loading = false;
      _locationMessage = location == null ? _locationError(permission) : null;
    });

    debugPrint('[SAFETY-MAP-DEBUG] isIncidentSpecific=$_isIncidentSpecific'
        ' incidentCount=${_deduplicatedIncidents.length}'
        ' selectedIncidentId=$_selectedIncidentId'
        ' incidentCenter=$_incidentCenter'
        ' disasters=${_disasters.length}');

    if (_incidentCenter != null) {
      debugPrint('[SAFETY-MAP-CAMERA]'
          ' mode=${_isIncidentSpecific ? "alert-specific" : "general-incident"}'
          ' centerLat=${_incidentCenter!.latitude}'
          ' centerLon=${_incidentCenter!.longitude}'
          ' greenRadiusKm=$_incidentGreenRadiusKm');
    }
    for (final d in _disasters) {
      debugPrint('[SAFETY-MAP-ZONES]'
          ' incidentId=${d.incidentId}'
          ' centerLat=${d.latitude}'
          ' centerLon=${d.longitude}'
          ' redRadiusMeters=${(d.redZoneKm * 1000).toStringAsFixed(0)}'
          ' yellowRadiusMeters=${(d.yellowZoneKm * 1000).toStringAsFixed(0)}'
          ' greenRadiusMeters=${(d.greenZoneKm * 1000).toStringAsFixed(0)}');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToDisasters();
    });
  }

  String _locationError(LocationPermissionStatus status) {
    return switch (status) {
      LocationPermissionStatus.denied => 'Location permission was denied.',
      LocationPermissionStatus.deniedForever =>
        'Location permission is disabled in app settings.',
      LocationPermissionStatus.serviceDisabled => 'Location services are off.',
      _ => 'Your current location is unavailable.',
    };
  }

  bool _isValidZone(DisasterZone zone) {
    return zone.active &&
        zone.radiusKm.isFinite &&
        zone.radiusKm > 0 &&
        zone.latitude.isFinite &&
        zone.latitude >= -90 &&
        zone.latitude <= 90 &&
        zone.longitude.isFinite &&
        zone.longitude >= -180 &&
        zone.longitude <= 180;
  }

  static (double, double, double) _zoneRadiiForSeverity(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL':
        return (3.0, 7.0, 15.0);
      case 'SEVERE':
        return (2.0, 5.0, 10.0);
      default:
        return (1.0, 3.0, 5.0);
    }
  }

  static EmergencySeverity _parseSeverity(String? severity) {
    final normalized = severity?.toUpperCase();
    return EmergencySeverity.values.firstWhere(
      (s) => s.name.toUpperCase() == normalized,
      orElse: () => EmergencySeverity.moderate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final disasterResult = location == null
        ? null
        : _nearestDisasterResult(location);
    final nearestCamp = location == null
        ? null
        : findNearestCamp(
            userLatitude: location.latitude,
            userLongitude: location.longitude,
            camps: _camps,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isIncidentSpecific
            ? 'Incident Safety Map'
            : 'Safety Map'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSafetyData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (!_isIncidentSpecific)
                    _buildIncidentDropdown(),
                  if (_isIncidentSpecific && widget.initialDisaster != null)
                    _incidentInfoCard(widget.initialDisaster!),
                  _statusCard(disasterResult, nearestCamp),
                  const SizedBox(height: 16),
                  _map(),
                  const SizedBox(height: 10),
                  _legend(),
                  if (_locationMessage != null) _locationUnavailable(),
                  if (location == null && !_isIncidentSpecific)
                    _infoCard(
                      Icons.location_off_outlined,
                      'Location unavailable',
                      'GPS is needed to calculate your safety status.',
                    ),
                  if (location != null && _disasters.isEmpty && !_isIncidentSpecific)
                    _infoCard(
                      Icons.check_circle_outline,
                      'No active disaster information',
                      'No verified active disaster information is available right now.',
                    ),
                  if (nearestCamp != null) ...[
                    const SizedBox(height: 16),
                    _campCard(nearestCamp, location!),
                  ],
                  if (location != null && nearestCamp == null) ...[
                    const SizedBox(height: 16),
                    _infoCard(
                      Icons.home_work_outlined,
                      'No verified safe locations nearby',
                      'Active camps with geographic coordinates will appear here when available.',
                    ),
                  ],
                  if (!_isIncidentSpecific) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/emergency_alerts'),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('View emergency alerts'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildIncidentDropdown() {
    if (_deduplicatedIncidents.isEmpty) return const SizedBox.shrink();

    final selectedExists = _selectedIncidentId != null &&
        _deduplicatedIncidents.any((i) => i.id == _selectedIncidentId);

    final safeSelectedId = selectedExists ? _selectedIncidentId : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: safeSelectedId,
        decoration: const InputDecoration(
          labelText: 'Disaster Incident',
          border: OutlineInputBorder(),
        ),
        items: _deduplicatedIncidents.map((incident) {
          debugPrint('[SAFETY-MAP-DROPDOWN] item id=${incident.id} name=${incident.name}');
          return DropdownMenuItem<String>(
            value: incident.id,
            child: Text(incident.name),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _selectedIncidentId = value);
          _loadSafetyData();
        },
      ),
    );
  }

  SafetyResult? _nearestDisasterResult(LocationResult location) {
    SafetyResult? nearest;
    for (final disaster in _disasters) {
      final result = SafetyCalculator.classifyWithFixedZones(
        userLatitude: location.latitude,
        userLongitude: location.longitude,
        disasterLatitude: disaster.latitude,
        disasterLongitude: disaster.longitude,
        redZoneKm: disaster.redZoneKm,
        yellowZoneKm: disaster.yellowZoneKm,
        greenZoneKm: disaster.greenZoneKm,
      );
      if (nearest == null ||
          result.distanceFromDisasterKm! < nearest.distanceFromDisasterKm!) {
        nearest = result;
      }
    }
    return nearest;
  }

  Widget _incidentInfoCard(DisasterZone disaster) {
    final severityLabel = switch (disaster.severity.name.toUpperCase()) {
      'CRITICAL' => 'CRITICAL',
      'SEVERE' => 'SEVERE',
      'MODERATE' => 'MODERATE',
      _ => 'MODERATE',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: disaster.severity == EmergencySeverity.critical ||
                            disaster.severity == EmergencySeverity.severe
                        ? Colors.red.shade700
                        : Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    disaster.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Severity: $severityLabel'),
            if (disaster.redZoneKm > 0)
              Text('🔴 High danger: ${disaster.redZoneKm.toStringAsFixed(1)} km radius'),
            if (disaster.yellowZoneKm > 0)
              Text('🟡 Caution: ${disaster.yellowZoneKm.toStringAsFixed(1)} km radius'),
            if (disaster.greenZoneKm > 0)
              Text('🟢 Lower-risk area: ${disaster.greenZoneKm.toStringAsFixed(1)} km radius'),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(SafetyResult? result, Camp? camp) {
    final zone = result?.zone ?? SafetyZone.unknown;
    final color = _zoneColor(zone);
    final label = switch (zone) {
      SafetyZone.red => 'HIGH DANGER',
      SafetyZone.yellow => 'CAUTION',
      SafetyZone.green => 'LOWER-RISK AREA',
      SafetyZone.safe => 'OUTSIDE ZONES',
      SafetyZone.unknown => 'LOCATION UNKNOWN',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR SAFETY STATUS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.shield_outlined, color: color, size: 30),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text('Nearest affected area: ${_nearestDisasterName()}'),
              if (result.distanceFromDisasterKm != null) ...[
                const SizedBox(height: 8),
                Text(
                  'You are ${result.distanceFromDisasterKm!.toStringAsFixed(1)} km from the disaster center.',
                ),
              ],
            ],
            if (camp != null) ...[
              const SizedBox(height: 6),
              Text('Nearest verified safe location: ${camp.name}'),
            ],
          ],
        ),
      ),
    );
  }

  String _nearestDisasterName() {
    if (_disasters.isEmpty) return 'Unavailable';
    var nearest = _disasters.first;
    var distance = SafetyCalculator.distanceKmBetween(
      _location!.latitude,
      _location!.longitude,
      nearest.latitude,
      nearest.longitude,
    );
    for (final disaster in _disasters.skip(1)) {
      final candidate = SafetyCalculator.distanceKmBetween(
        _location!.latitude,
        _location!.longitude,
        disaster.latitude,
        disaster.longitude,
      );
      if (candidate < distance) {
        nearest = disaster;
        distance = candidate;
      }
    }
    return nearest.title.isEmpty ? nearest.disasterType : nearest.title;
  }

  Widget _map() {
    final center = _getMapCenter();
    final zoom = _calculateZoomLevel();

    final markers = <Marker>[];
    final circles = <CircleMarker>[];

    if (_location != null) {
      final userPoint = LatLng(_location!.latitude, _location!.longitude);
      markers.add(
        Marker(
          point: userPoint,
          width: 84,
          height: 52,
          child: _marker(Icons.person_pin_circle, 'YOU', AppTheme.primaryColor),
        ),
      );
    }

    for (final disaster in _disasters) {
      final point = LatLng(disaster.latitude, disaster.longitude);
      markers.add(
        Marker(
          point: point,
          width: 110,
          height: 52,
          child: _marker(
            Icons.warning_amber_rounded,
            'INCIDENT',
            AppTheme.accentColor,
          ),
        ),
      );
      circles.add(
        CircleMarker(
          point: point,
          radius: disaster.redZoneKm * 1000,
          useRadiusInMeter: true,
          color: Colors.red.withAlpha(40),
          borderColor: Colors.red,
          borderStrokeWidth: 2,
        ),
      );
      circles.add(
        CircleMarker(
          point: point,
          radius: disaster.yellowZoneKm * 1000,
          useRadiusInMeter: true,
          color: Colors.amber.withAlpha(35),
          borderColor: Colors.amber.shade800,
          borderStrokeWidth: 2,
        ),
      );
      circles.add(
        CircleMarker(
          point: point,
          radius: disaster.greenZoneKm * 1000,
          useRadiusInMeter: true,
          color: Colors.green.withAlpha(30),
          borderColor: Colors.green,
          borderStrokeWidth: 2,
        ),
      );
    }
    for (final camp in _camps.where(
      (camp) => camp.latitude != null && camp.longitude != null && camp.active,
    )) {
      markers.add(
        Marker(
          point: LatLng(camp.latitude!, camp.longitude!),
          width: 90,
          height: 48,
          child: _marker(Icons.home_work_outlined, 'CAMP', Colors.teal),
        ),
      );
    }
    return SizedBox(
      height: 400,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey('map-${_incidentCenter?.latitude}-${_incidentCenter?.longitude}'),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.aasha.disasterconnect',
                ),
                CircleLayer(circles: circles),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'recenter-map',
                tooltip: _isIncidentSpecific
                    ? 'Center on incident'
                    : 'Center on my location',
                onPressed: _recenter,
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LatLng _getMapCenter() {
    if (_incidentCenter != null) {
      return _incidentCenter!;
    }
    if (_location != null) {
      return LatLng(_location!.latitude, _location!.longitude);
    }
    if (_disasters.isNotEmpty) {
      return LatLng(_disasters.first.latitude, _disasters.first.longitude);
    }
    return const LatLng(20.5937, 78.9629);
  }

  double _calculateZoomLevel() {
    if (_incidentGreenRadiusKm != null && _incidentGreenRadiusKm! > 0) {
      return _zoomForRadius(_incidentGreenRadiusKm!);
    }
    if (_disasters.isNotEmpty) {
      final maxGreenKm = _disasters
          .map((d) => d.greenZoneKm)
          .reduce((a, b) => a > b ? a : b);
      return _zoomForRadius(maxGreenKm);
    }
    return 11.0;
  }

  double _zoomForRadius(double greenRadiusKm) {
    const double paddingFactor = 1.3;
    final double targetRadiusM = greenRadiusKm * 1000 * paddingFactor;
    final double centerLat = _incidentCenter?.latitude ??
        (_location?.latitude ?? 20.5937);
    final double latRad = centerLat * pi / 180.0;
    const double tileSize = 256;
    const double maxZoom = 18.0;
    double zoom = 1.0;
    double worldRadius = tileSize / (2 * pi);
    for (double z = 1.0; z <= maxZoom; z++) {
      final double mapRadiusMeters =
          worldRadius * cos(latRad) * 2 * pi / (1 << z.toInt());
      if (mapRadiusMeters < targetRadiusM) {
        zoom = z;
      } else {
        break;
      }
    }
    return zoom.clamp(1.0, 13.0);
  }

  void _fitMapToDisasters() {
    if (!mounted) return;
    final center = _getMapCenter();
    final zoom = _calculateZoomLevel();
    debugPrint('[SAFETY-MAP-DEBUG] fitMap center=$center zoom=$zoom');
    try {
      _mapController.move(center, zoom);
    } catch (_) {
      debugPrint('[SAFETY-MAP-DEBUG] fitMap controller move failed, retrying');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(center, zoom);
          } catch (_) {}
        }
      });
    }
  }

  Widget _legend() => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: const [
          _LegendItem(color: Colors.red, label: '🔴 High danger'),
          _LegendItem(color: Colors.amber, label: '🟡 Caution'),
          _LegendItem(color: Colors.green, label: '🟢 Lower-risk area'),
          _LegendItem(color: Colors.teal, label: 'Camp'),
        ],
      ),
    ),
  );

  void _recenter() {
    _fitMapToDisasters();
  }

  Widget _marker(IconData icon, String label, Color color) => Column(
    children: [
      Icon(icon, color: color, size: 30),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    ],
  );

  Widget _locationUnavailable() => _infoCard(
    Icons.location_off_outlined,
    'Location unavailable',
    '$_locationMessage GPS is needed to calculate your safety status.',
  );

  Widget _infoCard(IconData icon, String title, String message) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppTheme.secondaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message),
    ),
  );

  Widget _campCard(Camp camp, LocationResult location) {
    final distance = SafetyCalculator.distanceKmBetween(
      location.latitude,
      location.longitude,
      camp.latitude!,
      camp.longitude!,
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.home_work_outlined, color: Colors.teal),
        title: Text(camp.name),
        subtitle: Text(
          '${distance.toStringAsFixed(1)} km away\n${camp.address}',
        ),
      ),
    );
  }

  Color _zoneColor(SafetyZone zone) => switch (zone) {
    SafetyZone.red => Colors.red.shade700,
    SafetyZone.yellow => Colors.amber.shade800,
    SafetyZone.green => Colors.green.shade700,
    SafetyZone.safe => Colors.teal,
    SafetyZone.unknown => AppTheme.secondaryColor,
  };
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
