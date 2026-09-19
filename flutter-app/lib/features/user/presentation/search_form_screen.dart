import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_state.dart';
import '../../../core/common_widgets/app_button.dart';
import '../../../core/common_widgets/app_text_field.dart';
import '../../../features/matching/data/models/match_request.dart';
import '../../images/data/image_selection_service.dart';
import '../../images/data/image_upload_api_service.dart';
import '../../images/data/local_image.dart';
import '../../images/presentation/image_source_picker.dart';
import '../../incidents/data/incident_repository.dart';
import '../../incidents/data/models/incident.dart';

class SearchFormScreen extends StatefulWidget {
  const SearchFormScreen({super.key});

  @override
  State<SearchFormScreen> createState() => _SearchFormScreenState();
}

class _SearchFormScreenState extends State<SearchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _detailsController = TextEditingController();
  final ImageSelectionService _imageSelection = LocalImageSelectionService();
  final ImageUploadApiService _imageUpload = HttpImageUploadApiService();
  late final IncidentRepository _incidentRepository;
  LocalImage? _selectedImage;
  bool _isSubmitting = false;
  bool _isLoadingIncidents = true;
  List<Incident> _deduplicatedIncidents = const [];
  String? _selectedIncidentId;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AppState>().authService;
    _incidentRepository = IncidentRepository(authService: authService);
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    try {
      final incidents = await _incidentRepository.getActiveSearchable();
      final uniqueMap = <String, Incident>{};
      for (final incident in incidents) {
        if (incident.id.isNotEmpty) {
          uniqueMap[incident.id] = incident;
        }
      }
      final deduplicated = uniqueMap.values.toList();
      debugPrint('[INCIDENT-UI-DEBUG] incident_count=${deduplicated.length}');
      debugPrint('[INCIDENT-UI-DEBUG] incidents=${deduplicated.map((i) => '${i.id}:${i.name}').join(', ')}');
      if (mounted) setState(() { _deduplicatedIncidents = deduplicated; _isLoadingIncidents = false; });
    } catch (error) {
      debugPrint('[INCIDENT-UI-DEBUG] search incident load failed: $error');
      debugPrint('[INCIDENT-UI-DEBUG] incident_load_error=$error');
      if (mounted) setState(() => _isLoadingIncidents = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final source = await chooseImageSource(context);
    if (source == null) return;
    try {
      final image = await _imageSelection.pickImage(source: source);
      if (image == null) return;
      final validation = await _imageSelection.validateImage(image);
      if (!validation.isValid) {
        _showMessage(validation.message ?? 'Invalid image.');
        return;
      }
      if (mounted) setState(() => _selectedImage = image);
    } catch (error, stackTrace) {
      debugPrint('[USER MATCH][IMAGE_PICK] failed: $error');
      debugPrint('$stackTrace');
      _showMessage('Unable to select the photo. Please try again.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    if (_selectedIncidentId == null) {
      _showMessage('Select an active disaster incident before searching.');
      return;
    }
    debugPrint('[INCIDENT-UI-DEBUG] selected_incident_id=$_selectedIncidentId');
    setState(() => _isSubmitting = true);
    try {
      String? photoReference;
      if (_selectedImage != null) {
        final requestId = 'match_${DateTime.now().microsecondsSinceEpoch}';
        final uploaded = await _imageUpload.uploadMatchInput(
          requestId: requestId,
          image: _selectedImage!,
        );
        photoReference = uploaded.storageId;
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/results',
        arguments: MatchRequest(
          incidentId: _selectedIncidentId!,
          name: _nameController.text.trim(),
          age: int.parse(_ageController.text),
          photoReference: photoReference,
          lastKnownLocation: _locationController.text.trim(),
          additionalDetails: _detailsController.text.trim(),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[USER MATCH][IMAGE_UPLOAD] failed: $error');
      debugPrint('$stackTrace');
      if (mounted) _showMessage('Unable to upload the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final dropdownEnabled = !_isLoadingIncidents && _deduplicatedIncidents.isNotEmpty;
    debugPrint('[INCIDENT-UI-DEBUG] loading=$_isLoadingIncidents dropdown_enabled=$dropdownEnabled');
    return Scaffold(
      appBar: AppBar(title: const Text('Missing Person Details')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter as much information as possible to help our AI find a match.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (_isLoadingIncidents)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  value: _selectedIncidentId,
                  decoration: const InputDecoration(
                    labelText: 'Disaster Incident',
                    helperText: 'Search is limited to this incident.',
                    border: OutlineInputBorder(),
                  ),
                  items: _deduplicatedIncidents.map((incident) => DropdownMenuItem(
                    value: incident.id,
                    child: Text(incident.name),
                  )).toList(),
                  onChanged: dropdownEnabled ? (value) => setState(() => _selectedIncidentId = value) : null,
                  validator: (value) => value == null ? 'Incident is required' : null,
                ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: _selectedImage == null
                          ? const Icon(Icons.add_a_photo, size: 50, color: Colors.grey)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(_selectedImage!.bytes, fit: BoxFit.cover),
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _choosePhoto,
                      icon: const Icon(Icons.add_a_photo),
                      label: Text(
                        _selectedImage == null
                            ? 'Upload Photo (Highly Recommended)'
                            : 'Change Photo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Full Name (Required)',
                hint: 'Enter full name',
                controller: _nameController,
                validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Age (Required)',
                hint: 'Enter age',
                keyboardType: TextInputType.number,
                controller: _ageController,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Age is required';
                  if (int.tryParse(val) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Last Known Location (Optional)',
                hint: 'Where was the person last seen?',
                controller: _locationController,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Additional Identifying Info (Optional)',
                hint: 'Tattoos, birthmarks, clothing, etc.',
                maxLines: 3,
                controller: _detailsController,
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Find Matches',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
