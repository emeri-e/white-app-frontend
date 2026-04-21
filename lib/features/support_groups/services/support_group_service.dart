import 'dart:convert';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/features/support_groups/models/support_group.dart';

class SupportGroupService {
  static const String _baseUrl = '${Env.apiBase}/support-groups';

  static List<SupportGroup>? cachedGroups;
  static Map<String, dynamic>? cachedCurrentSession;
  static List<dynamic>? cachedPosts;

  static Future<List<SupportGroup>> getGroups() async {
    final response = await ApiService.authorizedRequest(_baseUrl);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      cachedGroups = data.map((json) => SupportGroup.fromJson(json)).toList();
      return cachedGroups!;
    } else {
      throw Exception('Failed to load support groups: ${response.body}');
    }
  }

  static Future<SupportGroup> getGroupDetail(int id) async {
    final response = await ApiService.authorizedRequest('$_baseUrl/$id/');
    
    if (response.statusCode == 200) {
      return SupportGroup.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load group detail: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> joinGroup(int id, {String? transactionId}) async {
    final body = transactionId != null ? {'transaction_id': transactionId} : {};
    
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/$id/join/',
      method: 'POST',
      body: body,
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to join group: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getLiveKitToken(int id) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/$id/join-token/',
      method: 'POST',
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get LiveKit token: ${response.body}');
    }
  }

  static Future<List<dynamic>> getSessions(int id) async {
    final response = await ApiService.authorizedRequest('$_baseUrl/$id/sessions/');
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load sessions: ${response.body}');
    }
  }

  static Future<List<dynamic>> getTimelinePosts(int groupId) async {
    final response = await ApiService.authorizedRequest('$_baseUrl/$groupId/timeline/');
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load timeline posts: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> createTimelinePost(int groupId, String content, {bool isAnonymous = false}) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/$groupId/timeline/',
      method: 'POST',
      body: {
        'content_text': content,
        'is_anonymous': isAnonymous,
      },
    );
    
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create post: ${response.body}');
    }
  }

  static Future<void> reactToTimelinePost(int groupId, int postId, String type) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/$groupId/timeline/$postId/react/',
      method: 'POST',
      body: {'type': type},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to react to post: ${response.body}');
    }
  }


  static Future<Map<String, dynamic>?> getCurrentSession() async {
    final response = await ApiService.authorizedRequest('$_baseUrl/current-session/');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data == null) {
        cachedCurrentSession = null;
        return null;
      }
      cachedCurrentSession = data as Map<String, dynamic>;
      return cachedCurrentSession;
    } else {
      throw Exception('Failed to load current session: ${response.body}');
    }
  }
}
