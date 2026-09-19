import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../core/utils/location_service.dart';
import '../../../data/local/database/app_database.dart' as local;
import '../../../data/local/repositories/local_alert_repository.dart';
import '../../../data/sync/sync_service.dart';
import '../domain/safety_calculator.dart';
import 'emergency_repository.dart';
import 'models/disaster_zone.dart';
import 'models/emergency_alert.dart';
import 'models/user_sos.dart';
import 'models/official_sos.dart';

class SpringBootEmergencyRepository
    implements EmergencyRepository, OfficialSosRepository {
  SpringBootEmergencyRepository({
    http.Client? client,
    LocalAlertRepository? localAlerts,
    String? baseUrl,
    SyncService? syncService,
    AuthService? authService,
    this._tokenProvider,
  }) : _client = client ?? http.Client(),
       _localAlerts =
           localAlerts ??
           LocalAlertRepository(local.LocalDatabase.instance.database),
       _baseUrl = baseUrl ?? ApiConfig.matchingBaseUrl,
       _syncService = syncService ?? SyncService.instance,
       _authServiceOverride = authService {
    _syncService.configureSosSubmitter(_postSos);
  }

  final http.Client _client;
  final LocalAlertRepository _localAlerts;
  final String _baseUrl;
  final SyncService _syncService;
  final AuthService? _authServiceOverride;
  AuthService? _authService;
  final Future<String?> Function()? _tokenProvider;

  @override
  bool lastFetchUsedCache = false;

  @override
  String? lastError;

  @override
  Future<List<EmergencyAlert>> getActiveAlerts() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/alerts/active'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Alert request failed (${response.statusCode})');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Invalid alert response');
      }
      final alerts = <EmergencyAlert>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        try {
          alerts.add(EmergencyAlert.fromJson(value.cast<String, dynamic>()));
        } catch (error) {
          debugPrint('Skipping malformed emergency alert: $error');
        }
      }
      if (decoded.isNotEmpty && alerts.isEmpty) {
        throw const FormatException('No valid alerts in response');
      }
      await _localAlerts.replaceActive(alerts);
      lastFetchUsedCache = false;
      lastError = null;
      return alerts;
    } catch (error) {
      lastFetchUsedCache = true;
      lastError = error.toString();
      return _localAlerts.getActive();
    }
  }

  @override
  Future<List<DisasterZone>> getActiveDisasterZones() async {
    final alerts = await getActiveAlerts();
    return alerts
        .where(
          (alert) =>
              alert.latitude != null &&
              alert.longitude != null &&
              alert.radiusKm != null &&
              alert.radiusKm! > 0,
        )
        .map(
          (alert) => DisasterZone(
            id: alert.id,
            incidentId: alert.incidentId,
            disasterType: alert.disasterType,
            latitude: alert.latitude!,
            longitude: alert.longitude!,
            radiusKm: alert.radiusKm!,
            severity: alert.severity,
            title: alert.title,
            active: alert.active,
            redZoneKm: alert.redZoneKm,
            yellowZoneKm: alert.yellowZoneKm,
            greenZoneKm: alert.greenZoneKm,
          ),
        )
        .toList();
  }

  double? distanceFromUser(EmergencyAlert alert, LocationResult? location) {
    if (location == null || alert.latitude == null || alert.longitude == null) {
      return null;
    }
    return SafetyCalculator.distanceKmBetween(
      location.latitude,
      location.longitude,
      alert.latitude!,
      alert.longitude!,
    );
  }

  @override
  Future<SosSubmissionResult> submitSos(UserSos sos) async {
    final connectivity = await _safeConnectivityStatus();
    debugPrint('[SOS-DEBUG] connectivity=$connectivity');
    debugPrint('[SOS-DEBUG] apiBaseUrl=$_baseUrl');
    debugPrint('[SOS-DEBUG] attempting online SOS submission');
    try {
      await _postSos(sos.toJson());
      debugPrint('[SOS-DEBUG] request succeeded');
      return const SosSubmissionResult(
        state: SosDeliveryState.submitted,
        message: 'SOS sent. The emergency service confirmed receipt.',
      );
    } on SosHttpException catch (error) {
      debugPrint('[SOS-DEBUG] request failed type=HTTP_${error.statusCode}');
      debugPrint('[SOS-DEBUG] treating as offline=false');
      return SosSubmissionResult(
        state: SosDeliveryState.failed,
        message: _httpFailureMessage(error.statusCode),
      );
    } on TimeoutException catch (error) {
      debugPrint('[SOS-DEBUG] request failed type=TimeoutException');
      debugPrint('[SOS-DEBUG] treating as offline=true');
      return _queueAfterTransportFailure(sos, error);
    } on SocketException catch (error) {
      debugPrint('[SOS-DEBUG] request failed type=SocketException');
      debugPrint('[SOS-DEBUG] treating as offline=true');
      return _queueAfterTransportFailure(sos, error);
    } on http.ClientException catch (error) {
      debugPrint('[SOS-DEBUG] request failed type=ClientException');
      debugPrint('[SOS-DEBUG] treating as offline=true');
      return _queueAfterTransportFailure(sos, error);
    } on StateError catch (error) {
      debugPrint('[SOS-DEBUG] request failed type=AuthenticationOrClientState');
      debugPrint('[SOS-DEBUG] treating as offline=false');
      return SosSubmissionResult(
        state: SosDeliveryState.failed,
        message: error.message,
      );
    } catch (error) {
      debugPrint('[SOS-DEBUG] request failed type=${error.runtimeType}');
      debugPrint('[SOS-DEBUG] treating as offline=false');
      return SosSubmissionResult(
        state: SosDeliveryState.failed,
        message: 'SOS could not be sent. Please try again.',
      );
    }
  }

  Future<String> _safeConnectivityStatus() async {
    try {
      return (await Connectivity().checkConnectivity()).toString();
    } catch (_) {
      // Connectivity is diagnostic only. The configured backend request below
      // is the source of truth for whether SOS can be delivered.
      return 'unavailable';
    }
  }

  @override
  Future<List<OfficialSos>> getSosRequests({OfficialSosStatus? status}) async {
    final query = status == null ? '' : '?status=${status.name.toUpperCase()}';
    final token = await _loadToken();
    debugPrint(
      '[SOS-OFFICIAL-DEBUG] token_available=${token?.isNotEmpty == true} '
      'authorization_attached=${token?.isNotEmpty == true} endpoint=/api/sos$query',
    );
    final response = await _authorizedGet('/api/sos$query');
    debugPrint(
      '[SOS-OFFICIAL-DEBUG] response_status=${response.statusCode} '
      'response_is_list=${jsonDecode(response.body) is List}',
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('Invalid SOS list');
    final requests = <OfficialSos>[];
    for (final value in decoded) {
      if (value is! Map) continue;
      try {
        requests.add(OfficialSos.fromJson(value.cast<String, dynamic>()));
      } on FormatException catch (error) {
        debugPrint('Skipping malformed SOS request: $error');
      }
    }
    debugPrint(
      '[SOS-OFFICIAL-DEBUG] official_query_count=${requests.length} '
      'status_filter=${status?.name ?? 'ALL'} '
      'returned_sos_ids=${requests.map((request) => request.id).toList()}',
    );
    return requests;
  }

  @override
  Future<OfficialSos> getSosRequest(String id) async {
    final response = await _authorizedGet('/api/sos/$id');
    return OfficialSos.fromJson(jsonDecode(response.body));
  }

  @override
  Future<OfficialSos> updateSosStatus(
    String id,
    OfficialSosStatus status,
  ) async {
    final token = await _loadToken();
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/sos/$id/status'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status.name.toUpperCase()}),
    );
    if (response.statusCode != 200) {
      throw StateError('SOS status update failed (${response.statusCode})');
    }
    return OfficialSos.fromJson(jsonDecode(response.body));
  }

  Future<http.Response> _authorizedGet(String path) async {
    final token = await _loadToken();
    debugPrint(
      '[SOS-OFFICIAL-DEBUG] query_started endpoint=$path '
      'token_available=${token?.isNotEmpty == true} '
      'authorization_attached=${token?.isNotEmpty == true}',
    );
    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    debugPrint('[SOS-OFFICIAL-DEBUG] response_status=${response.statusCode}');
    if (response.statusCode != 200) {
      throw StateError('SOS request failed (${response.statusCode})');
    }
    debugPrint('[SOS-OFFICIAL-DEBUG] query_completed status=200');
    return response;
  }

  Future<void> _postSos(Map<String, dynamic> payload) async {
    final token = _tokenProvider == null
        ? await _loadToken()
        : await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw StateError('Authentication is required to submit SOS');
    }
    debugPrint('[SOS-DEBUG] request started id=${payload['id']}');
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/sos'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'id': payload['id'],
            'latitude': payload['latitude'],
            'longitude': payload['longitude'],
            'accuracy': payload['accuracy'],
            'message': payload['message'],
            'createdAt': payload['createdAt'],
          }),
        )
        .timeout(const Duration(seconds: 15));
    debugPrint('[SOS-DEBUG] response status=${response.statusCode}');
    debugPrint('[SOS-DEBUG] response body length=${response.body.length}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SosHttpException(response.statusCode);
    }
  }

  Future<SosSubmissionResult> _queueAfterTransportFailure(
    UserSos sos,
    Object error,
  ) async {
    debugPrint('[SOS-DEBUG] queueing locally after transport failure');
    await _syncService.saveSos(sos, attemptImmediate: false);
    return const SosSubmissionResult(
      state: SosDeliveryState.pendingLocal,
      message: 'SOS saved locally and will share when internet comes back.',
    );
  }

  String _httpFailureMessage(int statusCode) => switch (statusCode) {
    400 => 'SOS was rejected because its data was invalid.',
    401 => 'SOS could not be sent because authentication expired.',
    403 => 'You are not authorized to send this SOS.',
    500 => 'The SOS server encountered an error. Please try again.',
    _ => 'SOS server returned HTTP $statusCode.',
  };

  Future<String?> _loadToken() async {
    _authService ??= _authServiceOverride ?? AuthService();
    final auth = _authService!;
    await auth.tryAutoLogin();
    return auth.token;
  }
}

class SosHttpException implements Exception {
  SosHttpException(this.statusCode);

  final int statusCode;
}
