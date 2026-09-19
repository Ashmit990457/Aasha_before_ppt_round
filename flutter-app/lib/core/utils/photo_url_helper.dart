import 'dart:convert';
import '../config/api_config.dart';

class PhotoUrlHelper {
  PhotoUrlHelper._();

  /// Convert stored normal-photo references to a public delivery URL.
  /// 
  /// Matches the logic in main.py:_normal_photo_url.
  static String? getDisplayUrl(String? photoValue) {
    if (photoValue == null || photoValue.isEmpty) {
      return null;
    }
    
    if (photoValue.startsWith('http://') || photoValue.startsWith('https://')) {
      return photoValue;
    }
    
    // Relative URL from our backend (e.g. /api/v1/images/file/...)
    if (photoValue.startsWith('/')) {
      return '${ApiConfig.matchingBaseUrl}$photoValue';
    }
    
    String? storageId;
    try {
      final decoded = json.decode(photoValue);
      if (decoded is Map) {
        storageId = (decoded['storageId'] ?? decoded['storage_id']) as String?;
      } else if (decoded is String) {
        storageId = decoded;
      }
    } catch (_) {
      storageId = photoValue;
    }
    
    if (storageId != null && storageId.isNotEmpty && !storageId.contains('..')) {
      return '${ApiConfig.matchingBaseUrl}/api/v1/images/file/$storageId';
    }
    return null;
  }
}
