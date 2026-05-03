import 'dart:convert';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/features/tools/models/breathing_pattern.dart';
import 'package:whiteapp/features/tools/models/grounding_exercise.dart';
import 'package:whiteapp/features/tools/models/urge_surfing_config.dart';
import 'package:whiteapp/features/tools/models/flash_card.dart';
import 'package:whiteapp/features/tools/models/soundscape_track.dart';

class ToolsService {
  static Future<Map<String, dynamic>> getToolsOverview() async {
    final response = await ApiService.get('${Env.apiBase}/tools/overview/');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load tools overview');
  }

  static Future<List<BreathingPattern>> getBreathingPatterns() async {
    final response = await ApiService.get('${Env.apiBase}/tools/breathing/');
    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body);
      return list.map((model) => BreathingPattern.fromJson(model)).toList();
    }
    throw Exception('Failed to load breathing patterns');
  }

  static Future<List<GroundingExercise>> getGroundingExercises() async {
    final response = await ApiService.get('${Env.apiBase}/tools/grounding/');
    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body);
      return list.map((model) => GroundingExercise.fromJson(model)).toList();
    }
    throw Exception('Failed to load grounding exercises');
  }

  static Future<List<UrgeSurfingConfig>> getUrgeSurfingConfigs() async {
    final response = await ApiService.get('${Env.apiBase}/tools/urge-surfing/');
    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body);
      return list.map((model) => UrgeSurfingConfig.fromJson(model)).toList();
    }
    throw Exception('Failed to load urge surfing configs');
  }

  static Future<List<FlashCardDeck>> getFlashCardDecks() async {
    final response = await ApiService.get('${Env.apiBase}/tools/flashcards/decks/');
    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body);
      return list.map((model) => FlashCardDeck.fromJson(model)).toList();
    }
    throw Exception('Failed to load flashcard decks');
  }

  static Future<FlashCardDeck> getFlashCardDeck(int id) async {
    final response = await ApiService.get('${Env.apiBase}/tools/flashcards/decks/$id/');
    if (response.statusCode == 200) {
      return FlashCardDeck.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to load flashcard deck detail');
  }

  static Future<Map<String, dynamic>> getSoundscapeTracks() async {
    final response = await ApiService.get('${Env.apiBase}/tools/soundscape/');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      Iterable list = data['tracks'];
      List<SoundscapeTrack> tracks = list.map((model) => SoundscapeTrack.fromJson(model)).toList();
      return {
        'config': data['config'],
        'tracks': tracks,
      };
    }
    throw Exception('Failed to load soundscape tracks');
  }

  static Future<void> logToolUsage({
    required String toolType,
    int? toolConfigId,
    required int durationSeconds,
    required bool completed,
    Map<String, dynamic>? metadata,
  }) async {
    final body = {
      'tool_type': toolType,
      'tool_config_id': toolConfigId,
      'duration_seconds': durationSeconds,
      'completed': completed,
      if (metadata != null) 'metadata': metadata,
    };
    
    final response = await ApiService.post('${Env.apiBase}/tools/log/', body);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to log tool usage: ${response.body}');
    }
  }

  static Future<void> submitCardResponse({
    required int cardId,
    required String responseText,
  }) async {
    final body = {
      'card': cardId,
      'response_text': responseText,
    };
    
    final response = await ApiService.post('${Env.apiBase}/tools/flashcards/respond/', body);
    if (response.statusCode != 201) {
      throw Exception('Failed to submit card response: ${response.body}');
    }
  }
  static Future<FlashCardDeck> createUserDeck(String title, String description) async {
    final body = {
      'title': title,
      'description': description,
    };
    final response = await ApiService.post('${Env.apiBase}/tools/flashcards/decks/create/', body);
    if (response.statusCode == 201) {
      return FlashCardDeck.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create deck: ${response.body}');
  }

  static Future<FlashCard> addCardToDeck(int deckId, String questionText, String imagePath) async {
    final request = await ApiService.createMultipartRequest('POST', '${Env.apiBase}/tools/flashcards/cards/create/');
    request.fields['deck'] = deckId.toString();
    request.fields['question_text'] = questionText;
    await ApiService.addFileToMultipart(request, 'image', imagePath);
    
    final response = await ApiService.sendMultipartRequest(request);
    if (response.statusCode == 201) {
      return FlashCard.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to add card: ${response.body}');
  }
}
