import 'package:http/http.dart' as http;
import 'package:whiteapp/core/constants/env.dart';
import 'dart:convert';

import 'package:whiteapp/core/services/token_storage.dart';

class ApiService {
  // Use Env.apiBase for all requests

  static Future<http.Response> authorizedRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final accessToken = await TokenStorage.getAccessToken();

    headers ??= {};
    headers['Authorization'] = 'Bearer $accessToken';
    headers['Content-Type'] = 'application/json';

    http.Response response;

    final uri = Uri.parse(url);
    final jsonBody = body != null ? json.encode(body) : null;

    // Initial request
    response = await _makeRequest(uri, method, headers, jsonBody);

    if (response.statusCode == 401) {
      // Attempt to refresh token
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        final newAccess = await TokenStorage.getAccessToken();
        headers['Authorization'] = 'Bearer $newAccess';
        response = await _makeRequest(uri, method, headers, jsonBody);
      } else {
        // If refresh fails, clear and redirect to login
        await TokenStorage.clearTokens();
        // You can add navigation to login here if needed
        throw Exception('Session expired. Please log in again.');
      }
    }

    return response;
  }

  static Future<http.Response> get(String url) async {
    return authorizedRequest(url, method: 'GET');
  }

  static Future<http.Response> _makeRequest(
    Uri uri,
    String method,
    Map<String, String> headers,
    String? body,
  ) async {
    switch (method.toUpperCase()) {
      case 'POST':
        return await http.post(uri, headers: headers, body: body);
      case 'PUT':
        return await http.put(uri, headers: headers, body: body);
      case 'DELETE':
        return await http.delete(uri, headers: headers, body: body);
      default:
        return await http.get(uri, headers: headers);
    }
  }

  static Future<bool> _refreshAccessToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) return false;

    final url = Uri.parse('${Env.apiBase}/accounts/refresh/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final newAccess = data['access'];
      await TokenStorage.saveAccessToken(newAccess);
      return true;
    }

    return false;
  }

  static Future<Map<String, dynamic>> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse('${Env.apiBase}/accounts/signup/'),
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  static Future<void> firebaseLogin(String idToken) async {
    final response = await http.post(
      Uri.parse('${Env.apiBase}/accounts/firebase/'),
      body: {'idToken': idToken},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await TokenStorage.saveAccessToken(data['access']);
      await TokenStorage.saveRefreshToken(data['refresh']);
    } else {
      throw Exception('Failed to login with Firebase: ${response.body}');
    }
  }

  static Future<void> login(String email, String password) async {
    final url = Uri.parse('${Env.apiBase}/accounts/login/');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final access = data['access'];
      final refresh = data['refresh'];

      await TokenStorage.saveAccessToken(access);
      await TokenStorage.saveRefreshToken(refresh);
    } else {
      throw Exception('Login failed');
    }
  }

  static Future<void> socialLogin(String? idToken) async {
    final url = Uri.parse('${Env.apiBase}/accounts/login/');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'idToken': idToken}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final access = data['access'];
      final refresh = data['refresh'];

      await TokenStorage.saveAccessToken(access);
      await TokenStorage.saveRefreshToken(refresh);
    } else {
      throw Exception('Login failed');
    }
  }


  
  static Future<Map<String, dynamic>> resetPassword(String email, String password) async {
    final response = await http.post(
      Uri.parse('${Env.apiBase}/accounts/password-reset/'),
      body: {
        'email': email,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }


  static Future<Map<String, dynamic>> resetPasswordConfirm(String uid, String token, String newPassword) async {
    final response = await http.post(
      Uri.parse('${Env.apiBase}/accounts/password-reset/confirm'),
      body: {
        'uid': uid,
        'token': token,
        'new_password': newPassword
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }
  
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await authorizedRequest(
      '${Env.apiBase}/accounts/profile/',
      method: 'PUT',
      body: data,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }
}
