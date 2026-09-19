import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_service.dart';
import 'models/emergency_alert.dart';

class AlertManagementService {
  AlertManagementService({http.Client? client, AuthService? auth})
    : _client = client ?? http.Client(),
      _auth = auth ?? AuthService();

  final http.Client _client;
  final AuthService _auth;

  Future<List<EmergencyAlert>> getAll() async {
    final response = await _request(
      'GET',
      '/api/alerts',
      () => _client.get(_uri('/api/alerts'), headers: _headers),
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('Invalid alert list');
    return decoded
        .whereType<Map>()
        .map((item) => EmergencyAlert.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<EmergencyAlert> create(Map<String, dynamic> payload) async {
    final response = await _request(
      'POST',
      '/api/alerts',
      () => _client.post(
        _uri('/api/alerts'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
      expected: 201,
    );
    return EmergencyAlert.fromJson(jsonDecode(response.body));
  }

  Future<EmergencyAlert> update(String id, Map<String, dynamic> payload) async {
    final response = await _request(
      'PUT',
      '/api/alerts/$id',
      () => _client.put(
        _uri('/api/alerts/$id'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    return EmergencyAlert.fromJson(jsonDecode(response.body));
  }

  Future<EmergencyAlert> setActive(String id, bool active) async {
    final response = await _request(
      'PATCH',
      '/api/alerts/$id/active',
      () => _client.patch(
        _uri('/api/alerts/$id/active'),
        headers: _headers,
        body: jsonEncode({'active': active}),
      ),
    );
    return EmergencyAlert.fromJson(jsonDecode(response.body));
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.matchingBaseUrl}$path');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    ..._auth.authHeaders,
  };

  Future<http.Response> _request(
    String method,
    String endpoint,
    Future<http.Response> Function() request, {
    int expected = 200,
  }) async {
    await _auth.tryAutoLogin();
    final tokenAvailable = _auth.token?.isNotEmpty == true;
    debugPrint('[ALERT-DEBUG] endpoint=$endpoint');
    debugPrint('[ALERT-DEBUG] method=$method');
    debugPrint('[ALERT-DEBUG] token_available=$tokenAvailable');
    debugPrint('[ALERT-DEBUG] authorization_attached=$tokenAvailable');
    final response = await request().timeout(const Duration(seconds: 15));
    debugPrint('[ALERT-DEBUG] response_status=${response.statusCode}');
    if (response.statusCode != expected) {
      throw StateError(
        'Government alert request failed (${response.statusCode})',
      );
    }
    return response;
  }
}
