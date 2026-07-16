import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/constants/env.dart';

class HeroService {
  static const String baseUrl = '${Env.apiBase}/recovery/heroes';

  /// Checks the current user's eligibility and invitation status.
  static Future<Map<String, dynamic>> checkEligibility() async {
    final response = await ApiService.get('$baseUrl/onboarding-check/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      // 404 indicates the user is not currently in the HeroProfile table (i.e. not eligible)
      return {'status': 'not_eligible'};
    } else {
      throw Exception('Failed to check eligibility status');
    }
  }

  /// Submits the user's recovery narrative, category, and alias.
  static Future<Map<String, dynamic>> submitStory({
    required String storySummary,
    required String programCategory,
    required String alias,
  }) async {
    final response = await ApiService.post(
      '$baseUrl/submit-story/',
      {
        'story_summary': storySummary,
        'program_category': programCategory,
        'alias': alias,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to submit recovery story');
    }
  }

  /// Submits the signed consent for the live broadcast session.
  static Future<Map<String, dynamic>> signConsent({
    String termsVersion = 'v1.0',
  }) async {
    final response = await ApiService.post(
      '$baseUrl/sign-consent/',
      {
        'terms_text_version': termsVersion,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit signed terms consent');
    }
  }

  /// Retrieves available schedule slots for live events.
  static Future<List<dynamic>> getAvailableSlots() async {
    final response = await ApiService.get('$baseUrl/available-slots/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch available slots');
    }
  }

  /// Books a slot for a live session.
  static Future<Map<String, dynamic>> bookSlot(int slotId) async {
    final response = await ApiService.post('$baseUrl/book-slot/$slotId/', {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to book live session slot');
    }
  }

  /// Submits T-shirt size and shipping address for reward delivery.
  static Future<Map<String, dynamic>> submitShipping({
    required String tshirtSize,
    required String recipientName,
    required String addressLine1,
    String addressLine2 = '',
    required String city,
    required String state,
    required String postalCode,
    required String country,
  }) async {
    final response = await ApiService.post(
      '$baseUrl/shipping/',
      {
        'tshirt_size': tshirtSize,
        'recipient_name': recipientName,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to submit shipping details');
    }
  }

  /// Fetches reward shipping details.
  static Future<Map<String, dynamic>?> getShippingDetails() async {
    final response = await ApiService.get('$baseUrl/shipping/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load shipping details');
    }
  }

  /// Fetches all published hero profiles (optionally filtered by category).
  static Future<List<dynamic>> getPublishedHeroes({String? category}) async {
    String url = '$baseUrl/wall/';
    if (category != null && category.toLowerCase() != 'all') {
      url += '?category=${category.toLowerCase()}';
    }
    final response = await ApiService.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load Hero wall profiles');
    }
  }

  /// Fetches upcoming live sessions (events).
  static Future<List<dynamic>> getUpcomingEvents() async {
    try {
      final heroes = await getPublishedHeroes();
      final List<dynamic> upcoming = [];
      final now = DateTime.now();

      for (var hero in heroes) {
        final events = hero['events'] as List<dynamic>? ?? [];
        for (var event in events) {
          final scheduledTime = DateTime.parse(event['scheduled_time']);
          if (scheduledTime.isAfter(now)) {
            // Append hero alias and profile details for convenience
            upcoming.add({
              ...event,
              'hero_alias': hero['alias'] ?? 'Guest Hero',
              'hero_id': hero['id'],
              'clean_days': hero['clean_days'] ?? 180,
              'program_category': hero['program_category'],
            });
          }
        }
      }
      // Sort upcoming events by closest scheduled time first
      upcoming.sort((a, b) => DateTime.parse(a['scheduled_time'])
          .compareTo(DateTime.parse(b['scheduled_time'])));
      return upcoming;
    } catch (e) {
      debugPrint("Error fetching upcoming events: $e");
      return [];
    }
  }

  /// Fetches past recorded VODs.
  static Future<List<dynamic>> getVods() async {
    try {
      final heroes = await getPublishedHeroes();
      final List<dynamic> vods = [];

      for (var hero in heroes) {
        final events = hero['events'] as List<dynamic>? ?? [];
        for (var event in events) {
          if (event['vod_url'] != null && event['vod_url'].toString().isNotEmpty) {
            vods.add({
              ...event,
              'hero_alias': hero['alias'] ?? 'Guest Hero',
              'hero_id': hero['id'],
              'clean_days': hero['clean_days'] ?? 180,
              'program_category': hero['program_category'],
            });
          }
        }
      }
      return vods;
    } catch (e) {
      debugPrint("Error fetching VODs: $e");
      return [];
    }
  }

  /// Fetches details of the active/current live player event.
  static Future<Map<String, dynamic>?> getActiveLivePlayer() async {
    final response = await ApiService.get('$baseUrl/live-player/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load active live player details');
    }
  }

  /// Gets all approved comments for a specific hero wall.
  static Future<List<dynamic>> getComments(int heroId) async {
    final response = await ApiService.get('$baseUrl/wall/$heroId/comment/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch hero profile comments');
    }
  }

  /// Posts a comment to a hero wall.
  static Future<Map<String, dynamic>> postComment(int heroId, String commentText) async {
    final response = await ApiService.post(
      '$baseUrl/wall/$heroId/comment/',
      {'comment_text': commentText},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to post comment to hero wall');
    }
  }

  /// Registers/toggles a reaction (like/love) on a hero wall.
  static Future<void> reactToHero(int heroId, String reactionType, bool isAdding) async {
    if (isAdding) {
      final response = await ApiService.post(
        '$baseUrl/wall/$heroId/reaction/',
        {'reaction_type': reactionType},
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to register reaction');
      }
    } else {
      final response = await ApiService.authorizedRequest(
        '$baseUrl/wall/$heroId/reaction/',
        method: 'DELETE',
        body: {'reaction_type': reactionType},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to remove reaction');
      }
    }
  }
}
