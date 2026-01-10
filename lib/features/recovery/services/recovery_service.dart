import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whiteapp/core/services/api_service.dart';

import 'package:whiteapp/core/constants/env.dart';

class RecoveryService {
  static const String baseUrl = '${Env.apiBase}/recovery';

  static Future<Map<String, dynamic>> getDailyQuote() async {
    final response = await ApiService.get('$baseUrl/quote/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
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

  static Future<List<dynamic>> getChallenges() async {
    final response = await ApiService.get('$baseUrl/challenges/');
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

  static Future<void> markChallengeComplete(int challengeId) async {
    final response = await ApiService.authorizedRequest(
      '$baseUrl/challenges/progress/',
      method: 'POST',
      body: {'challenge': challengeId},
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to mark challenge complete');
    }
  }
  static Future<List<dynamic>> getUserEnrollments() async {
    final response = await ApiService.get('$baseUrl/enrollments/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
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

  static Future<Map<String, dynamic>> getProgressDashboard() async {
    final response = await ApiService.get('$baseUrl/dashboard/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load progress dashboard');
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
}
