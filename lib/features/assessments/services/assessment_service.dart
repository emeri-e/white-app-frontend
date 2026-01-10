import 'dart:convert';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/features/assessments/models/assessment.dart';

import 'package:whiteapp/core/constants/env.dart';

class AssessmentService {
  static const String _baseUrl = '${Env.apiBase}/assessments';

  static Future<List<Assessment>> getAssessments() async {
    final response = await ApiService.get('$_baseUrl/');
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Assessment.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load assessments');
    }
  }

  static Future<Assessment> getAssessmentDetail(int id) async {
    final response = await ApiService.get('$_baseUrl/$id/');
    if (response.statusCode == 200) {
      return Assessment.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load assessment details');
    }
  }

  static Future<UserAssessmentResult> submitAssessment(int id, Map<int, int> responses) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/$id/submit/',
      method: 'POST',
      body: {'responses': responses.map((key, value) => MapEntry(key.toString(), value))},
    );

    if (response.statusCode == 201) {
      return UserAssessmentResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to submit assessment');
    }
  }
  
  static Future<List<UserAssessmentResult>> getHistory() async {
    final response = await ApiService.get('$_baseUrl/history/');
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => UserAssessmentResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load history');
    }
  }
}
