import 'dart:convert';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/api_service.dart';

class FeedbackService {
  static const String _baseUrl = '${Env.apiBase}/feedback/feedback/';

  static Future<void> submitFeedback({
    required String message,
    required String type,
  }) async {
    final response = await ApiService.authorizedRequest(
      _baseUrl,
      method: 'POST',
      body: {
        'message': message,
        'type': type,
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to submit feedback: ${response.body}');
    }
  }

  static Future<List<dynamic>> getMyFeedback() async {
    final response = await ApiService.authorizedRequest(_baseUrl);
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load feedback history: ${response.body}');
    }
  }
}
