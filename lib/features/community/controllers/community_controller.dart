import 'package:flutter/material.dart';
import 'package:whiteapp/core/services/community_service.dart';
import 'package:whiteapp/features/community/models/community_post.dart';
import 'package:whiteapp/features/community/models/post_comment.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';

class CommunityController extends ChangeNotifier {
  final CommunityService _communityService;

  CommunityController({required CommunityService communityService}) : _communityService = communityService;

  List<CommunityPost> _posts = [];
  List<CommunityPost> _recoveryStories = [];
  bool _isLoading = false;
  String? _error;
  int? _selectedChallengeDay;
  int? _selectedLevelId;
  int? _selectedChallengeId;
  bool _showOriginalLanguage = false;

  List<CommunityPost> get posts => _posts;
  List<CommunityPost> get recoveryStories => _recoveryStories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get selectedChallengeDay => _selectedChallengeDay;
  int? get selectedLevelId => _selectedLevelId;
  int? get selectedChallengeId => _selectedChallengeId;
  bool get showOriginalLanguage => _showOriginalLanguage;

  List<dynamic> _levels = [];
  List<dynamic> _challenges = [];

  List<dynamic> get levels => _levels;
  List<dynamic> get challenges => _challenges;

  /// Fetch posts for a specific challenge day (or current day)
  Future<void> fetchPosts({int? challengeDay, int? levelId, int? challengeId}) async {
    _isLoading = true;
    _error = null;
    _selectedChallengeDay = challengeDay;
    _selectedLevelId = levelId;
    _selectedChallengeId = challengeId;
    notifyListeners();

    try {
      _posts = await _communityService.getPosts(
        challengeDay: challengeDay,
        levelId: levelId,
        challengeId: challengeId,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch program details (levels and challenges) for filters
  Future<void> fetchProgramDetails() async {
    try {
      // Get dashboard stats to find active program ID
      final stats = await ProgressService.getDashboardStats();
      final programId = stats['active_program_id'];
      
      if (programId != null) {
        _levels = await ProgressService.getLevels(programId);
        _challenges = await ProgressService.getChallenges(programId);
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching program details: $e');
    }
  }

  /// Fetch recovery stories
  Future<void> fetchRecoveryStories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recoveryStories = await _communityService.getRecoveryStories();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new post
  Future<bool> createPost(CommunityPost post) async {
    try {
      final newPost = await _communityService.createPost(post);
      _posts.insert(0, newPost);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update an existing post
  Future<bool> updatePost(int id, CommunityPost post) async {
    try {
      final updatedPost = await _communityService.updatePost(id, post);
      final index = _posts.indexWhere((p) => p.id == id);
      if (index != -1) {
        _posts[index] = updatedPost;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a post
  Future<bool> deletePost(int id) async {
    try {
      await _communityService.deletePost(id);
      _posts.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Add a comment to a post
  Future<bool> addComment(PostComment comment) async {
    try {
      await _communityService.addComment(comment);
      // Refresh posts to get updated comment count
      await fetchPosts(
        challengeDay: _selectedChallengeDay,
        levelId: _selectedLevelId,
        challengeId: _selectedChallengeId,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Report a post or comment
  Future<bool> reportContent({int? postId, int? commentId, required String reason}) async {
    try {
      await _communityService.reportContent(
        postId: postId,
        commentId: commentId,
        reason: reason,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Report translation issue
  Future<bool> reportTranslation(int postId, String language) async {
    try {
      await _communityService.reportTranslation(postId, language);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle original language display
  void toggleOriginalLanguage() {
    _showOriginalLanguage = !_showOriginalLanguage;
    notifyListeners();
  }

  /// React to a post (like)
  Future<bool> reactToPost(int postId, String type) async {
    try {
      await _communityService.reactToPost(postId, type);
      // Refresh to get updated reaction count
      await fetchPosts(
        challengeDay: _selectedChallengeDay,
        levelId: _selectedLevelId,
        challengeId: _selectedChallengeId,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get original (untranslated) post content
  Future<Map<String, dynamic>> showOriginal(int postId) async {
    try {
      return await _communityService.showOriginal(postId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
