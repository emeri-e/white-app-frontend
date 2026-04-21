import 'dart:convert';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/features/profile/models/user_profile.dart';

class ProfileService {
  static const String _baseUrl = '${Env.apiBase}/accounts/profile/';

  static UserProfile? cachedProfile;

  static Future<UserProfile> getProfile() async {
    final response = await ApiService.authorizedRequest(_baseUrl);
    
    if (response.statusCode == 200) {
      cachedProfile = UserProfile.fromJson(json.decode(response.body));
      return cachedProfile!;
    } else {
      throw Exception('Failed to load profile: ${response.body}');
    }
  }

  static Future<UserProfile> updateProfile(Map<String, dynamic> data) async {
    final response = await ApiService.authorizedRequest(
      _baseUrl,
      method: 'PUT',
      body: data,
    );
    
    if (response.statusCode == 200) {
      return UserProfile.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getPublicProfile(int userId) async {
    final response = await ApiService.authorizedRequest('${Env.apiBase}/accounts/profile/$userId/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load public profile: ${response.body}');
    }
  }
}
