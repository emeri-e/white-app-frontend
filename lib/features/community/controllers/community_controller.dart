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
  List<CommunityPost> _pendingPosts = [];
  bool _isLoading = false;
  String? _error;
  int? _selectedChallengeDay;
  int? _selectedLevelId;
  int? _selectedChallengeId;
  int? _assignedLevelId;
  String? _assignedLevelTitle;
  List<Map<String, dynamic>> _myGroupChallenges = [];
  bool _showOriginalLanguage = false;

  List<CommunityPost> get posts => _posts;
  List<CommunityPost> get recoveryStories => _recoveryStories;
  List<CommunityPost> get pendingPosts => _pendingPosts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get selectedChallengeDay => _selectedChallengeDay;
  int? get selectedLevelId => _selectedLevelId;
  int? get selectedChallengeId => _selectedChallengeId;
  int? get assignedLevelId => _assignedLevelId;
  String? get assignedLevelTitle => _assignedLevelTitle;
  List<Map<String, dynamic>> get myGroupChallenges => _myGroupChallenges;
  int? get assignedChallengeId => _myGroupChallenges.isNotEmpty ? _myGroupChallenges.first['id'] : null;
  String? get primaryChallengeTitle => _myGroupChallenges.isNotEmpty ? _myGroupChallenges.first['title'] : null;
  bool get showOriginalLanguage => _showOriginalLanguage;

  List<dynamic> _levels = [];
  List<dynamic> _challenges = [];

  List<dynamic> get levels => _levels;
  List<dynamic> get challenges => _challenges;

  /// Fetch posts with optional filters. If no filters are provided, uses the currently selected ones.
  Future<void> fetchPosts({int? challengeDay, int? levelId, int? challengeId, bool useDefaults = true}) async {
    _isLoading = true;
    _error = null;
    
    // Update internal state if explicit values provided
    if (challengeDay != null) _selectedChallengeDay = challengeDay;
    if (levelId != null) {
      _selectedLevelId = levelId;
      _selectedChallengeId = null; // Mutual exclusivity
    }
    if (challengeId != null) {
      _selectedChallengeId = challengeId;
      _selectedLevelId = null; // Mutual exclusivity
    }
    
    // If we want to clear everything (e.g. "All" filter)
    if (!useDefaults && levelId == null && challengeId == null && challengeDay == null) {
        _selectedLevelId = null;
        _selectedChallengeId = null;
        _selectedChallengeDay = null;
    }

    notifyListeners();

    try {
      final fetchedPosts = await _communityService.getPosts(
        challengeDay: _selectedChallengeDay,
        levelId: _selectedLevelId,
        challengeId: _selectedChallengeId,
      );
      _posts = fetchedPosts;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchRecoveryStories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final stories = await _communityService.getRecoveryStories();
      _recoveryStories = stories;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  Future<void> fetchPendingPosts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final pending = await _communityService.getPendingPosts();
      _pendingPosts = pending;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> createPost(CommunityPost post) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _communityService.createPost(post);
      _posts.insert(0, response);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePost(int id, CommunityPost post) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _communityService.updatePost(id, post);
      final index = _posts.indexWhere((p) => p.id == id);
      if (index != -1) {
        _posts[index] = response;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePost(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _communityService.deletePost(id);
      _posts.removeWhere((p) => p.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchProgramDetails() async {
    try {
      final stats = await ProgressService.getDashboardStats();
      if (stats != null) {
        final activeProgram = stats['active_program'];
        if (activeProgram != null) {
          final programId = activeProgram['id'];
          final levels = await ProgressService.getLevels(programId);
          final challenges = await ProgressService.getChallenges(programId);
          
          _levels = levels;
          _challenges = challenges;

          final statusType = stats['current_status_type'];
          final statusId = stats['current_status_id'];
          
          if (statusType == 'level') {
            _assignedLevelId = statusId;
            _assignedLevelTitle = stats['current_status'];
          }

          // Build My Group Challenges list
          final Map<int, Map<String, dynamic>> challengesMap = {};
          
          // 1. If backend says current status is a challenge, add it first (highest priority)
          if (statusType == 'challenge' && statusId != null) {
              // We need the title. Let's find it in the challenges list if possible.
              final challengeData = _challenges.firstWhere((c) => c['id'] == statusId, orElse: () => null);
              if (challengeData != null) {
                  challengesMap[statusId] = {'id': statusId, 'title': challengeData['title']};
              }
          }

          // 2. Add all active challenges
          final activeChallenges = stats['active_challenges'] as List? ?? [];
          for (var c in activeChallenges) {
              final id = c['id'] as int;
              if (!challengesMap.containsKey(id)) {
                  challengesMap[id] = {'id': id, 'title': c['title']};
              }
          }

          // 3. Add all available challenges
          final availableChallenges = stats['available_challenges'] as List? ?? [];
          for (var c in availableChallenges) {
              final id = c['id'] as int;
              if (!challengesMap.containsKey(id)) {
                  challengesMap[id] = {'id': id, 'title': c['title']};
              }
          }

          _myGroupChallenges = challengesMap.values.toList();
          
          // Sort myGroupChallenges so "Step" comes first or alphanumeric sort
          _myGroupChallenges.sort((a, b) {
              final tA = (a['title'] as String).toLowerCase();
              final tB = (b['title'] as String).toLowerCase();
              if (tA.contains('step') && !tB.contains('step')) return -1;
              if (!tA.contains('step') && tB.contains('step')) return 1;
              return tA.compareTo(tB);
          });

          // Set default filter if nothing is selected yet
          if (_selectedLevelId == null && _selectedChallengeId == null) {
            _selectedLevelId = _assignedLevelId;
            _selectedChallengeId = assignedChallengeId;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching program details: $e");
    }
  }

  void toggleLanguage() {
    _showOriginalLanguage = !_showOriginalLanguage;
    notifyListeners();
  }

  Future<bool> reactToPost(int postId, String reactionType) async {
    try {
      await _communityService.reactToPost(postId, reactionType);
      fetchPosts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addComment(PostComment comment) async {
    try {
      await _communityService.addComment(comment);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reportContent({int? postId, int? commentId, required String reason}) async {
    try {
      await _communityService.reportContent(postId: postId, commentId: commentId, reason: reason);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> showOriginal(int postId) async {
    try {
      return await _communityService.showOriginal(postId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

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

  Future<bool> approvePost(int postId) async {
    try {
      await _communityService.approvePost(postId);
      fetchPosts();
      fetchPendingPosts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectPost(int postId, {String reason = ''}) async {
    try {
      await _communityService.rejectPost(postId, reason: reason);
      fetchPosts();
      fetchPendingPosts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

}
