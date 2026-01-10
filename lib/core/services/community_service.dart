import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/features/community/models/community_post.dart';
import 'package:whiteapp/features/community/models/post_comment.dart';

class CommunityService {
  static const String _baseUrl = '${Env.apiBase}/community';

  /// Get posts with optional challenge_day filter
  Future<List<CommunityPost>> getPosts({
    int? challengeDay,
    int? levelId,
    int? challengeId,
  }) async {
    String url = '$_baseUrl/posts/?';
    if (challengeDay != null) {
      url += 'challenge_day=$challengeDay&';
    }
    if (levelId != null) {
      url += 'level_id=$levelId&';
    }
    if (challengeId != null) {
      url += 'challenge_id=$challengeId&';
    }

    final response = await ApiService.authorizedRequest(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => CommunityPost.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load posts: ${response.body}');
    }
  }

  /// Get recovery stories feed
  Future<List<CommunityPost>> getRecoveryStories() async {
    final response =
        await ApiService.authorizedRequest('$_baseUrl/posts/recovery_stories/');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => CommunityPost.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load recovery stories: ${response.body}');
    }
  }

  /// Create a new post
  Future<CommunityPost> createPost(CommunityPost post) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/posts/',
      method: 'POST',
      body: post.toJson(),
    );

    if (response.statusCode == 201) {
      return CommunityPost.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create post: ${response.body}');
    }
  }

  /// Update an existing post
  Future<CommunityPost> updatePost(int id, CommunityPost post) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/posts/$id/',
      method: 'PUT',
      body: post.toJson(),
    );

    if (response.statusCode == 200) {
      return CommunityPost.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update post: ${response.body}');
    }
  }

  /// Delete a post
  Future<void> deletePost(int id) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/posts/$id/',
      method: 'DELETE',
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete post: ${response.body}');
    }
  }

  /// Get original (untranslated) post content
  Future<Map<String, dynamic>> showOriginal(int postId) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/posts/$postId/show_original/',
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get original post: ${response.body}');
    }
  }

  /// Report a translation issue
  Future<void> reportTranslation(int postId, String language) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/posts/$postId/report_translation/',
      method: 'POST',
      body: {'language': language},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to report translation: ${response.body}');
    }
  }

  /// Add a comment to a post
  Future<PostComment> addComment(PostComment comment) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/comments/',
      method: 'POST',
      body: comment.toJson(),
    );

    if (response.statusCode == 201) {
      return PostComment.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add comment: ${response.body}');
    }
  }

  /// Report post or comment
  Future<void> reportContent({
    int? postId,
    int? commentId,
    required String reason,
  }) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/reports/',
      method: 'POST',
      body: {
        if (postId != null) 'post': postId,
        if (commentId != null) 'comment': commentId,
        'reason': reason,
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to report content: ${response.body}');
    }
  }

  /// React to a post (like)
  Future<void> reactToPost(int postId, String reactionType) async {
    final response = await ApiService.authorizedRequest(
      '$_baseUrl/reactions/',
      method: 'POST',
      body: {
        'post': postId,
        'type': reactionType,
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to react to post: ${response.body}');
    }
  }
}
