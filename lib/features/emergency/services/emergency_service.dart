import 'dart:convert';
import 'package:whiteapp/core/services/api_service.dart';

class EmergencyService {
  Future<Map<String, dynamic>> getSOSStatus() async {
    final response = await ApiService.get('/api/emergency/status/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load SOS status');
  }

  Future<Map<String, dynamic>> triggerSOS(String option, {Map<String, dynamic>? metadata}) async {
    final response = await ApiService.post('/api/emergency/trigger/', {
      'option': option,
      'metadata': metadata ?? {},
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to trigger SOS');
  }

  Future<Map<String, dynamic>> createSOSPost(String contentText) async {
    final response = await ApiService.post('/api/emergency/sos-post/', {
      'content_text': contentText,
    });
    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    final error = json.decode(response.body);
    throw Exception(error['error'] ?? 'Failed to create SOS post');
  }

  Future<List<dynamic>> getSOSPosts() async {
    final response = await ApiService.get('/api/emergency/sos-posts/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load SOS posts');
  }

  Future<List<dynamic>> getAvailableSpecialists() async {
    final response = await ApiService.get('/api/specialists/profiles/available/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load available specialists');
  }

  Future<Map<String, dynamic>> getMySupervisorAssignment() async {
    final response = await ApiService.get('/api/specialists/supervisor/my-assignment/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load supervisor assignment');
  }
}
