import 'dart:convert';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/api_service.dart';

class RewardsService {
  static const String _baseUrl = '${Env.apiBase}/rewards';

  static Future<Map<String, dynamic>> getWallet() async {
    final response = await ApiService.get('$_baseUrl/wallet/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load wallet');
    }
  }

  static Future<List<dynamic>> getBadges() async {
    final response = await ApiService.get('$_baseUrl/badges/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load badges');
    }
  }

  static Future<List<dynamic>> getMyBadges() async {
    final response = await ApiService.get('$_baseUrl/my-badges/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load my badges');
    }
  }

  static Future<Map<String, dynamic>> purchaseBadge(int badgeId) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/badges/$badgeId/purchase/',
      method: 'POST',
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body)['error'] ?? 'Failed to purchase badge';
      throw Exception(error);
    }
  }

  static Future<void> donate(int amountGems, {bool isRecurring = false}) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/donate/',
      method: 'POST',
      body: {
        'amount_gems': amountGems,
        'donation_type': isRecurring ? 'monthly' : 'one_time',
      },
    );

    if (response.statusCode != 201) {
      final error = json.decode(response.body)['error'] ?? 'Failed to donate';
      throw Exception(error);
    }
  }
}
