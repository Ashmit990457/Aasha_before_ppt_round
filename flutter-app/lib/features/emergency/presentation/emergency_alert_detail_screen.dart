import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../data/models/disaster_zone.dart';
import '../data/models/emergency_alert.dart';
import '../../incidents/data/incident_repository.dart';
import '../../incidents/data/models/incident.dart';

class EmergencyAlertDetailScreen extends StatefulWidget {
  const EmergencyAlertDetailScreen({super.key, required this.alert});

  final EmergencyAlert alert;

  @override
  State<EmergencyAlertDetailScreen> createState() => _EmergencyAlertDetailScreenState();
}

class _EmergencyAlertDetailScreenState extends State<EmergencyAlertDetailScreen> {
  late final IncidentRepository _incidentRepository;
  Incident? _incident;
  bool _loadingIncident = false;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AppState>().authService;
    _incidentRepository = IncidentRepository(authService: authService);
    if (widget.alert.incidentId != null) {
      _loadIncident();
    }
  }

  Future<void> _loadIncident() async {
    if (widget.alert.incidentId == null) return;
    setState(() => _loadingIncident = true);
    try {
      final incident = await _incidentRepository.getById(widget.alert.incidentId!);
      if (mounted) setState(() => _incident = incident);
    } catch (error) {
      debugPrint('[ALERT-DETAIL] Failed to load incident: $error');
    } finally {
      if (mounted) setState(() => _loadingIncident = false);
    }
  }

  // Determine the best available location for the safety map
  ({double latitude, double longitude, double radiusKm, String severity, double redZoneKm, double yellowZoneKm, double greenZoneKm, String title})? get _mapLocation {
    // Prefer alert's own location (zone radii are always computed from severity)
    if (widget.alert.latitude != null &&
        widget.alert.longitude != null &&
        widget.alert.greenZoneKm > 0) {
      return (
        latitude: widget.alert.latitude!,
        longitude: widget.alert.longitude!,
        radiusKm: widget.alert.greenZoneKm,
        severity: widget.alert.severity.name.toUpperCase(),
        redZoneKm: widget.alert.redZoneKm,
        yellowZoneKm: widget.alert.yellowZoneKm,
        greenZoneKm: widget.alert.greenZoneKm,
        title: widget.alert.title,
      );
    }
    // Fall back to incident's location
    if (_incident != null &&
        _incident!.latitude != null &&
        _incident!.longitude != null) {
      final incidentRadius = _incident!.radiusKm ??
          (_incident!.greenZoneKm ?? _defaultGreenZone(_incident!.severity));
      if (incidentRadius > 0) {
        return (
          latitude: _incident!.latitude!,
          longitude: _incident!.longitude!,
          radiusKm: incidentRadius,
          severity: _incident!.severity?.toUpperCase() ?? 'MODERATE',
          redZoneKm: _incident!.redZoneKm ?? _defaultRedZone(_incident!.severity),
          yellowZoneKm: _incident!.yellowZoneKm ?? _defaultYellowZone(_incident!.severity),
          greenZoneKm: _incident!.greenZoneKm ?? _defaultGreenZone(_incident!.severity),
          title: _incident!.name,
        );
      }
    }
    return null;
  }

  static double _defaultRedZone(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL': return 3.0;
      case 'SEVERE': return 2.0;
      default: return 1.0;
    }
  }

  static double _defaultYellowZone(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL': return 7.0;
      case 'SEVERE': return 5.0;
      default: return 3.0;
    }
  }

  static double _defaultGreenZone(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL': return 15.0;
      case 'SEVERE': return 10.0;
      default: return 5.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapLocation = _mapLocation;
    final hasArea = mapLocation != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Alert')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.alert.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(widget.alert.message),
          const SizedBox(height: 20),
          _row('Severity', widget.alert.severity.name.toUpperCase()),
          _row('Type', widget.alert.disasterType),
          if (widget.alert.district != null) _row('District', widget.alert.district!),
          if (widget.alert.state != null) _row('State', widget.alert.state!),
          if (widget.alert.radiusKm != null)
            _row('Affected radius', '${widget.alert.radiusKm!.toStringAsFixed(1)} km'),
          _row('Issued', widget.alert.createdAt.toLocal().toString()),
          if (hasArea) ...[
            const SizedBox(height: 24),
            if (_loadingIncident)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else
              FilledButton.icon(
                onPressed: () {
                  final zone = DisasterZone(
                    id: widget.alert.id,
                    incidentId: widget.alert.incidentId ?? _incident?.id,
                    disasterType: widget.alert.disasterType,
                    latitude: mapLocation.latitude,
                    longitude: mapLocation.longitude,
                    radiusKm: mapLocation.radiusKm,
                    severity: EmergencySeverity.values.firstWhere(
                      (s) => s.name.toUpperCase() == mapLocation.severity,
                      orElse: () => EmergencySeverity.moderate,
                    ),
                    title: mapLocation.title,
                    active: widget.alert.active,
                    redZoneKm: mapLocation.redZoneKm,
                    yellowZoneKm: mapLocation.yellowZoneKm,
                    greenZoneKm: mapLocation.greenZoneKm,
                  );
                  debugPrint('[ALERT-SAFETY-MAP-NAV]'
                      ' alertId=${widget.alert.id}'
                      ' incidentId=${zone.incidentId}'
                      ' latitude=${zone.latitude}'
                      ' longitude=${zone.longitude}'
                      ' severity=${zone.severity}'
                      ' redZoneKm=${zone.redZoneKm}'
                      ' yellowZoneKm=${zone.yellowZoneKm}'
                      ' greenZoneKm=${zone.greenZoneKm}'
                      ' initialDisasterExists=true');
                  Navigator.pushNamed(
                    context,
                    '/safety_map',
                    arguments: zone,
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Safety Map'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text('$label: $value'),
  );
}
