import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../../../features/auth/data/auth_service.dart';
import 'models/incident.dart';

class IncidentRepository {
  IncidentRepository({this.authService});

  final AuthService? authService;

  Future<String?> _getToken() async {
    final service = authService;
    if (service != null) {
      await service.tryAutoLogin();
      return service.token;
    }
    return null;
  }

  void _log(String message) {
    // ignore: avoid_print
    print(message);
  }

  Future<List<Incident>> getActiveSearchable() async {
    final token = await _getToken();
    _log('[INCIDENT-UI-DEBUG] endpoint=/api/incidents/active');
    _log('[INCIDENT-UI-DEBUG] token_available=${token?.isNotEmpty == true}');
    _log('[INCIDENT-UI-DEBUG] authorization_attached=${token?.isNotEmpty == true}');
    
    final response = await http
        .get(
          Uri.parse('${ApiConfig.matchingBaseUrl}/api/incidents/active'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    
    _log('[INCIDENT-UI-DEBUG] response_status=${response.statusCode}');
    
    if (response.statusCode != 200) {
      _log('[INCIDENT-UI-DEBUG] incident_load_error=HTTP ${response.statusCode}');
      throw Exception('Unable to load active incidents (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final incidents = decoded
        .whereType<Map<String, dynamic>>()
        .map(Incident.fromJson)
        .where((incident) => incident.id.isNotEmpty)
        .toList();
    
    _log('[INCIDENT-UI-DEBUG] incident_count=${incidents.length}');
    _log('[INCIDENT-UI-DEBUG] incidents=${incidents.map((i) => '${i.id}:${i.name}').join(', ')}');
    return incidents;
  }

  Future<Incident?> getById(String id) async {
    final token = await _getToken();
    _log('[INCIDENT-UI-DEBUG] endpoint=/api/incidents/$id');
    _log('[INCIDENT-UI-DEBUG] token_available=${token?.isNotEmpty == true}');
    
    final response = await http
        .get(
          Uri.parse('${ApiConfig.matchingBaseUrl}/api/incidents/$id'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    
    _log('[INCIDENT-UI-DEBUG] response_status=${response.statusCode}');
    
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Unable to load incident (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return Incident.fromJson(decoded);
  }
}
