import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whiteapp/core/services/api_service.dart';

import 'package:whiteapp/core/constants/env.dart';

class RecoveryService {
  static const String baseUrl = '${Env.apiBase}/recovery';

  static Map<String, dynamic>? cachedQuote;

  static Future<Map<String, dynamic>> getDailyQuote() async {
    final response = await ApiService.get('$baseUrl/quote/');
    if (response.statusCode == 200) {
      cachedQuote = jsonDecode(response.body);
      return cachedQuote!;
    } else {
      throw Exception('Failed to load quote');
    }
  }

  static Future<List<dynamic>> getPrograms() async {
    final response = await ApiService.get('$baseUrl/programs/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load programs');
    }
  }

  static Future<List<dynamic>> getLevels(int programId) async {
    final response = await ApiService.get('$baseUrl/levels/?program_id=$programId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load levels');
    }
  }

  static Future<List<dynamic>> getChallenges({String? status}) async {
    String url = '$baseUrl/challenges/';
    if (status != null) {
      url += '?status=$status';
    }
    final response = await ApiService.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load challenges');
    }
  }
  
  static Future<Map<String, dynamic>> getLevelDetails(int levelId) async {
    final response = await ApiService.get('$baseUrl/levels/$levelId/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load level details');
    }
  }

  static Future<List<dynamic>> getExercises(int levelId) async {
    final response = await ApiService.get('$baseUrl/levels/$levelId/exercises/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load exercises');
    }
  }

  static Future<Map<String, dynamic>> markLevelComplete(int levelId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/levels/$levelId/complete/',
      method: 'POST',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to mark level complete');
    }
  }

  static Future<Map<String, dynamic>> markChallengeComplete(int challengeId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/challenges/progress/',
      method: 'POST',
      body: {'challenge': challengeId},
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to mark challenge complete');
    }
  }

  static Future<Map<String, dynamic>> startChallenge(int challengeId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/challenges/progress/',
      method: 'POST',
      body: {'challenge': challengeId, 'action': 'start'},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to start challenge');
    }
  }

  static Future<Map<String, dynamic>> updateChallengeTask(int challengeId, dynamic taskId, bool isCompleted) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/challenges/progress/',
      method: 'POST',
      body: {
        'challenge': challengeId,
        'action': 'update_task',
        'task_id': taskId,
        'is_completed': isCompleted,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update challenge task');
    }
  }

  static List<dynamic>? cachedEnrollments;

  static Future<List<dynamic>> getUserEnrollments() async {
    final response = await ApiService.get('$baseUrl/enrollments/');
    if (response.statusCode == 200) {
      cachedEnrollments = jsonDecode(response.body);
      return cachedEnrollments!;
    } else {
      throw Exception('Failed to load enrollments');
    }
  }

  static Future<void> enrollInProgram(int programId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/enrollments/',
      method: 'POST',
      body: {'program': programId},
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to enroll in program');
    }
  }

  static Future<void> switchProgram(int programId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/enrollments/switch/',
      method: 'PATCH',
      body: {'program_id': programId},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to switch program');
    }
  }

  static Map<String, dynamic>? cachedDashboardData;

  static Future<Map<String, dynamic>> getProgressDashboard() async {
    final response = await ApiService.get('$baseUrl/dashboard/');
    if (response.statusCode == 200) {
      cachedDashboardData = jsonDecode(response.body);
      return cachedDashboardData!;
    } else {
      throw Exception('Failed to load progress dashboard');
    }
  }
  
  static Map<String, dynamic>? cachedDailyLearningSummary;

  static Future<Map<String, dynamic>> getDailyLearningSummary() async {
    final response = await ApiService.get('$baseUrl/daily-learning-summary/');
    if (response.statusCode == 200) {
      cachedDailyLearningSummary = jsonDecode(response.body);
      return cachedDailyLearningSummary!;
    } else {
      throw Exception('Failed to load daily learning summary');
    }
  }

  static Future<void> logMediaTime(int mediaId, int seconds) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/media/$mediaId/log-time/',
      method: 'POST',
      body: {'seconds': seconds},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to log media time');
    }
  }

  static Future<void> markMediaComplete(int mediaId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/media/$mediaId/complete/',
      method: 'POST',
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark media complete');
    }
  }

  static Future<Map<String, dynamic>> submitExercise(int exerciseId, String answer) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/exercises/$exerciseId/submit/',
      method: 'POST',
      body: {'answer': answer},
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit exercise');
    }
  }

  static Future<void> likeMedia(int mediaId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/media/$mediaId/like/',
      method: 'POST',
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to like media');
    }
  }

  static Future<void> unlikeMedia(int mediaId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/media/$mediaId/unlike/',
      method: 'POST',
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to unlike media');
    }
  }

  static Future<void> postComment(int mediaId, String content) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/media/$mediaId/comment/',
      method: 'POST',
      body: {'content': content},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to post comment');
    }
  }

  static Future<Map<String, dynamic>> getComments(int mediaId, {int page = 1}) async {
    final response = await ApiService.get('$baseUrl/media/$mediaId/comments/?page=$page');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load comments');
    }
  }

  static Future<void> saveMediaProgress(int mediaId, int lastPositionSeconds) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/media/$mediaId/progress/',
      method: 'PATCH',
      body: {'last_position_seconds': lastPositionSeconds},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save media progress');
    }
  }

  static Future<String> fetchSubtitles(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load subtitles');
    }
  }
}
