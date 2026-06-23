import 'dart:convert';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/constants/env.dart';
import '../models/buddy_pairing.dart';

class BuddyService {
  static String get _baseUrl => Env.apiBase;

  /// POST /api/buddy/invite/ -> Returns created pending pairing
  static Future<BuddyPairing> generateInvite(String buddyEmail) async {
    final response = await ApiService.post(
      '$_baseUrl/api/buddy/invite/',
      {'buddy_email': buddyEmail},
    );

    if (response.statusCode == 201) {
      return BuddyPairing.fromJson(json.decode(response.body));
    } else {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// GET /api/buddy/invite/<code>/ -> Returns invite details
  static Future<BuddyPairing> checkInviteStatus(String code) async {
    final response = await ApiService.get('$_baseUrl/api/buddy/invite/$code/');

    if (response.statusCode == 200) {
      return BuddyPairing.fromJson(json.decode(response.body));
    } else {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// POST /api/buddy/accept/ -> Activates the pairing with PIN
  static Future<BuddyPairing> acceptInvite(String code, String pin) async {
    final response = await ApiService.post(
      '$_baseUrl/api/buddy/accept/',
      {'invite_code': code, 'pin': pin},
    );

    if (response.statusCode == 200) {
      return BuddyPairing.fromJson(json.decode(response.body));
    } else {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// GET /api/buddy/status/ -> Returns current active pairing details
  static Future<BuddyPairing?> getPairingStatus() async {
    final response = await ApiService.get('$_baseUrl/api/buddy/status/');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data == null || data.isEmpty) {
        return null;
      }
      return BuddyPairing.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// POST /api/buddy/verify-pin/ -> Returns true if valid PIN
  static Future<bool> verifyPIN(String pin) async {
    final response = await ApiService.post(
      '$_baseUrl/api/buddy/verify-pin/',
      {'pin': pin},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['valid'] == true;
    } else {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// POST /api/buddy/remove/ -> Unlinks buddy pairing
  static Future<Map<String, dynamic>> removeBuddy(String reason, String pin) async {
    final response = await ApiService.post(
      '$_baseUrl/api/buddy/remove/',
      {'removal_reason': reason, 'pin': pin},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// GET /api/buddy/dashboard/ -> Fetches buddy recovery data dashboard
  static Future<BuddyDashboardData> getBuddyDashboard() async {
    final response = await ApiService.get('$_baseUrl/api/buddy/dashboard/');

    if (response.statusCode == 200) {
      return BuddyDashboardData.fromJson(json.decode(response.body));
    } else {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// POST /api/buddy/emergency-lock/ -> Elevates device to MAX shields
  static Future<void> triggerEmergencyLock() async {
    final response = await ApiService.post(
      '$_baseUrl/api/buddy/emergency-lock/',
      {},
    );

    if (response.statusCode != 200) {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// POST /api/buddy/emergency-unlock/ -> Restores shields using security PIN
  static Future<void> unlockEmergency(String pin) async {
    final response = await ApiService.post(
      '$_baseUrl/api/buddy/emergency-unlock/',
      {'pin': pin},
    );

    if (response.statusCode != 200) {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  /// POST /api/buddy/reset-pin/ -> Updates PIN
  static Future<void> resetPIN(String currentPin, String newPin) async {
    final response = await ApiService.post(
      '$_baseUrl/api/buddy/reset-pin/',
      {'current_pin': currentPin, 'new_pin': newPin},
    );

    if (response.statusCode != 200) {
      final errorMsg = _parseError(response.body);
      throw Exception(errorMsg);
    }
  }

  static String _parseError(String body) {
    try {
      final data = json.decode(body);
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'].toString();
        if (data.containsKey('error')) return data['error'].toString();
        if (data.containsKey('non_field_errors')) return (data['non_field_errors'] as List).join(', ');
        
        final firstValue = data.values.first;
        if (firstValue is List) return firstValue.join(', ');
        return firstValue.toString();
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}
