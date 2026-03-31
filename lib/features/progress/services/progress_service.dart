import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/services/token_storage.dart';

import 'package:whiteapp/features/progress/models/mood_entry.dart';
import 'package:whiteapp/features/progress/models/relapse_entry.dart';
import 'package:whiteapp/features/progress/models/program_tracker_entry.dart';

class ProgressService {
  static const String _recoveryUrl = '${Env.apiBase}/recovery';
  static const String _emotionsUrl = '${Env.apiBase}/emotions';

  static Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await ApiService.get('$_recoveryUrl/dashboard/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load dashboard data');
    }
  }

  static Future<List<MoodEntry>> getMoodHistory() async {
    final response = await ApiService.get('$_emotionsUrl/');
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => MoodEntry.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load mood history');
    }
  }

  static Future<Map<String, dynamic>> getDailyCheckup() async {
    final response = await ApiService.get('$_emotionsUrl/daily-checkup/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load daily checkup');
    }
  }

  static Future<void> logMood(MoodEntry entry) async {
    final response = await ApiService.authorizedRequest(
      '$_emotionsUrl/create/',
      method: 'POST',
      body: entry.toJson(),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to log mood');
    }
  }

  static Future<void> logRelapse(RelapseEntry entry) async {
    if (entry.audioPath != null) {
      // Multipart request for audio
      final request = http.MultipartRequest('POST', Uri.parse('$_emotionsUrl/relapse/create/'));
      
      // Add headers (Auth)
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add fields
      request.fields['date'] = entry.date;
      if (entry.cause != null) request.fields['cause'] = entry.cause!;
      if (entry.emotions != null) request.fields['emotions'] = entry.emotions!;
      if (entry.notes != null) request.fields['notes'] = entry.notes!;

      // Add file
      request.files.add(await http.MultipartFile.fromPath('audio_log', entry.audioPath!));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 201) {
        throw Exception('Failed to log relapse with audio: ${response.body}');
      }
    } else {
      // Standard JSON request
      final response = await ApiService.authorizedRequest(
        '$_emotionsUrl/relapse/create/',
        method: 'POST',
        body: entry.toJson(),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to log relapse');
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getRelapseTrend(String range) async {
    final response = await ApiService.authorizedRequest(
      '$_emotionsUrl/relapse/trend/?range=$range',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load relapse trend');
    }
  }

  static Future<void> logTrackerEntry(ProgramTrackerEntry entry) async {
    final response = await ApiService.authorizedRequest(
      '$_recoveryUrl/trackers/',
      method: 'POST',
      body: entry.toJson(),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to log tracker entry');
    }
  }

  static Future<void> logToolUsage(String toolType, int durationSeconds) async {
    final response = await ApiService.authorizedRequest(
      '$_emotionsUrl/tools/create/',
      method: 'POST',
      body: {
        'tool_type': toolType,
        'duration_seconds': durationSeconds,
      },
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to log tool usage');
    }
  }
  static Future<List<dynamic>> getLevels(int programId) async {
    final response = await ApiService.authorizedRequest(
      '$_recoveryUrl/levels/?program_id=$programId',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load levels');
    }
  }

  static Future<List<dynamic>> getChallenges(int programId) async {
    final response = await ApiService.authorizedRequest(
      '$_recoveryUrl/challenges/?program_id=$programId',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load challenges');
    }
  }
  static Future<List<dynamic>> getPrograms() async {
    final response = await ApiService.authorizedRequest(
      '$_recoveryUrl/programs/',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load programs');
    }
  }

  static Future<Map<String, dynamic>> getProgressSummary() async {
    final response = await ApiService.get('$_recoveryUrl/progress/summary-7d/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load progress summary');
    }
  }

  static Future<Map<String, dynamic>> getCalendarData(int year, int month) async {
    final response = await ApiService.get('$_recoveryUrl/progress/calendar/?year=$year&month=$month');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load calendar data');
    }
  }

  static Future<Map<String, dynamic>> getAssessmentGraphs() async {
    final response = await ApiService.get('${Env.apiBase}/assessments/history-graphs/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load assessment graphs');
    }
  }
}
