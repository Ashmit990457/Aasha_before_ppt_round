import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../data/alert_management_service.dart';
import '../data/models/emergency_alert.dart';

class GovernmentAlertsManagementScreen extends StatefulWidget {
  const GovernmentAlertsManagementScreen({super.key, this.service});

  final AlertManagementService? service;

  @override
  State<GovernmentAlertsManagementScreen> createState() =>
      _GovernmentAlertsManagementScreenState();
}

class _GovernmentAlertsManagementScreenState
    extends State<GovernmentAlertsManagementScreen> {
  late final AlertManagementService _service =
      widget.service ?? AlertManagementService();
  List<EmergencyAlert> _alerts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final alerts = await _service.getAll();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final payload = await _showEditor();
    if (payload == null) return;
    await _run(() => _service.create(payload), 'Alert created');
  }

  Future<void> _edit(EmergencyAlert alert) async {
    final payload = await _showEditor(alert);
    if (payload == null) return;
    await _run(() => _service.update(alert.id, payload), 'Alert updated');
  }

  Future<void> _toggle(EmergencyAlert alert) async {
    await _run(
      () => _service.setActive(alert.id, !alert.active),
      alert.active ? 'Alert deactivated' : 'Alert published',
    );
  }

  Future<void> _run(
    Future<EmergencyAlert> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Government alert action failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppState>().isHeadOfficial) {
      return const Scaffold(
        body: Center(child: Text('Government alert management is restricted.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Government Emergency Alerts'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_alert),
        label: const Text('Create alert'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: _alerts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No government alerts yet.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      itemBuilder: (_, index) => _card(_alerts[index]),
                    ),
            ),
    );
  }

  Widget _card(EmergencyAlert alert) => Card(
    child: ListTile(
      title: Text(alert.title),
      subtitle: Text(
        '${alert.disasterType} • ${alert.severity.name.toUpperCase()}\n'
        '${alert.active ? 'ACTIVE / PUBLISHED' : 'INACTIVE / DRAFT'}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') _edit(alert);
          if (value == 'toggle') _toggle(alert);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(
            value: 'toggle',
            child: Text(alert.active ? 'Deactivate' : 'Publish / activate'),
          ),
        ],
      ),
    ),
  );

  Future<Map<String, dynamic>?> _showEditor([EmergencyAlert? alert]) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AlertFormDialog(alert: alert),
    );
  }
}

class _AlertFormDialog extends StatefulWidget {
  const _AlertFormDialog({this.alert});

  final EmergencyAlert? alert;

  @override
  State<_AlertFormDialog> createState() => _AlertFormDialogState();
}

class _AlertFormDialogState extends State<_AlertFormDialog> {
  late final _title = TextEditingController(text: widget.alert?.title ?? '');
  late final _message = TextEditingController(
    text: widget.alert?.message ?? '',
  );
  late final _type = TextEditingController(
    text: widget.alert?.disasterType ?? 'GENERAL',
  );
  late final _district = TextEditingController(
    text: widget.alert?.district ?? '',
  );
  late final _state = TextEditingController(text: widget.alert?.state ?? '');
  late final _latitude = TextEditingController(
    text: widget.alert?.latitude?.toString() ?? '',
  );
  late final _longitude = TextEditingController(
    text: widget.alert?.longitude?.toString() ?? '',
  );
  late final _radius = TextEditingController(
    text: widget.alert?.radiusKm?.toString() ?? '',
  );
  EmergencySeverity _severity = EmergencySeverity.moderate;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _severity = widget.alert?.severity ?? EmergencySeverity.moderate;
    if (widget.alert?.latitude != null && widget.alert?.longitude != null) {
      _selectedLocation = LatLng(widget.alert!.latitude!, widget.alert!.longitude!);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _message,
      _type,
      _district,
      _state,
      _latitude,
      _longitude,
      _radius,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.alert == null
          ? 'Create government alert'
          : 'Edit government alert',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_title, 'Title'),
          _field(_message, 'Message', maxLines: 3),
          _field(_type, 'Type'),
          DropdownButtonFormField<EmergencySeverity>(
            initialValue: _severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: EmergencySeverity.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _severity = value!),
          ),
          _field(_district, 'District (optional)'),
          _field(_state, 'State (optional)'),
          const SizedBox(height: 8),
          _locationPicker(),
          const SizedBox(height: 8),
          _field(
            _radius,
            'Affected radius km (optional)',
            keyboard: TextInputType.number,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save draft')),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _locationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Disaster Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latitude,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _longitude,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openLocationPicker,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Select on Map'),
        ),
        if (_selectedLocation != null) ...[
          const SizedBox(height: 4),
          Text(
            'Selected: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ],
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (_) => _LocationPickerDialog(
        initialLocation: _selectedLocation,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result;
        _latitude.text = result.latitude.toString();
        _longitude.text = result.longitude.toString();
      });
    }
  }

  void _submit() {
    if (_title.text.trim().isEmpty || _type.text.trim().isEmpty) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a disaster location on the map.')),
      );
      return;
    }
    double? number(String value) => double.tryParse(value.trim());
    Navigator.pop(context, {
      'title': _title.text.trim(),
      'message': _message.text.trim(),
      'type': _type.text.trim(),
      'severity': _severity.name.toUpperCase(),
      'district': _district.text.trim().isEmpty ? null : _district.text.trim(),
      'state': _state.text.trim().isEmpty ? null : _state.text.trim(),
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'radiusKm': number(_radius.text),
      'active': widget.alert?.active ?? false,
    });
  }
}

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  final _mapController = MapController();
  LatLng? _pickedLocation;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation ?? const LatLng(20.5937, 78.9629); // Default to India center
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              title: const Text('Select Disaster Location'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pickedLocation!,
                  initialZoom: 6,
                  onTap: (tapPosition, point) {
                    setState(() => _pickedLocation = point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.aasha.disasterconnect',
                  ),
                  if (_pickedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pickedLocation!,
                          width: 60,
                          height: 60,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Latitude: ${_pickedLocation!.latitude.toStringAsFixed(6)}\n'
                      'Longitude: ${_pickedLocation!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _pickedLocation),
                    child: const Text('Confirm Location'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
