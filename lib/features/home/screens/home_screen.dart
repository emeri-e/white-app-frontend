import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
import 'package:whiteapp/features/profile/models/user_profile.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/features/recovery/screens/program_list_screen.dart';
import 'package:whiteapp/features/recovery/screens/challenge_list_screen.dart';
import 'package:whiteapp/features/recovery/screens/level_list_screen.dart';
import 'package:whiteapp/features/recovery/screens/level_detail_screen.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/constants/env.dart';
import 'package:provider/provider.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';

import 'package:whiteapp/features/community/screens/community_feed_screen.dart';
import 'package:whiteapp/features/support_groups/screens/support_group_list_screen.dart';
import 'package:whiteapp/features/profile/screens/profile_screen.dart';
import 'package:whiteapp/features/progress/screens/progress_screen.dart';
import 'package:whiteapp/features/progress/widgets/relapse_trend_chart.dart';
import 'package:whiteapp/features/support_groups/services/support_group_service.dart';
import 'package:whiteapp/features/support_groups/models/support_group.dart';
import 'package:whiteapp/core/services/notification_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:whiteapp/features/progress/screens/mood_checkin_screen.dart';
import 'package:whiteapp/features/progress/screens/relapse_log_screen.dart';
import 'package:whiteapp/features/assessments/screens/assessment_list_screen.dart';
import 'package:whiteapp/features/assessments/screens/assessment_detail_screen.dart';
import 'package:whiteapp/features/community/models/community_post.dart';
import 'package:whiteapp/core/services/community_service.dart';
import 'package:whiteapp/features/home/widgets/home_widgets.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/features/progress/models/mood_entry.dart';
import 'package:whiteapp/features/progress/models/relapse_entry.dart';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whiteapp/features/home/widgets/support_group_session_widget.dart';

class HomeScreen extends StatefulWidget {
  static const String id = 'home_screen';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  // Vertical PageController for HomeTab
  final PageController _verticalPageController = PageController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _verticalPageController.addListener(_onVerticalScroll);
    NotificationService.initialize();
  }

  @override
  void dispose() {
    _verticalPageController.removeListener(_onVerticalScroll);
    _verticalPageController.dispose();
    super.dispose();
  }

  void _onVerticalScroll() {
    if (_verticalPageController.hasClients) {
      // page can be null initially
      final page = _verticalPageController.page ?? 0.0;
      // Clamp between 0.0 and 1.0 just in case of overscroll
      setState(() {
        _scrollProgress = page.clamp(0.0, 1.0);
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showEmergencyBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Emergency Tools',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a tool to help you stay grounded right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 24),
                _buildEmergencyToolTile(context, 'Breathing', Icons.air, 'breathing_screen', Colors.lightBlueAccent),
                _buildEmergencyToolTile(context, '5-4-3-2-1 Grounding', Icons.visibility, 'grounding_screen', Colors.tealAccent),
                const Divider(color: Colors.white24, height: 32),
                _buildEmergencyToolTile(context, 'Urge Surfing', Icons.waves, 'urge_surfing_screen', Colors.indigoAccent),
                _buildEmergencyToolTile(context, 'Flash Cards', Icons.style, 'flash_cards_screen', Colors.pinkAccent),
                _buildEmergencyToolTile(context, 'Soundscape', Icons.headphones, 'soundscape_screen', Colors.purpleAccent),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyToolTile(BuildContext context, String title, IconData icon, String route, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      onTap: () {
        Navigator.pop(context); // Close bottom sheet
        Navigator.pushNamed(context, route);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we are not on Home tab, we treat it as "Dashboard" view (progress 1.0)
    // or keep the background static at 1.0
    final effectiveProgress = _selectedIndex == 0 ? _scrollProgress : 1.0;

    return Scaffold(
      extendBody: true, // Allows background to extend behind the nav bar
      resizeToAvoidBottomInset: false, // Prevent keyboard from squeezing bottom nav
      body: AbstractBackground(
        scrollProgress: effectiveProgress,
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              HomeTab(pageController: _verticalPageController),
              const CommunityFeedScreen(),
              const SupportGroupListScreen(),
              const ProgressScreen(),
              const ProfileScreen(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmergencyBottomSheet(context),
        backgroundColor: Colors.redAccent.withOpacity(0.9),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: (_selectedIndex == 0 && _scrollProgress < 0.5) ? const Offset(0, 1) : const Offset(0, 0),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded),
              label: 'Community',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_call_rounded),
              label: 'Therapy',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final PageController pageController;
  const HomeTab({super.key, required this.pageController});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isLoading = ProfileService.cachedProfile == null;
  UserProfile? _profile = ProfileService.cachedProfile;
  Map<String, dynamic>? _quote = RecoveryService.cachedQuote;
  List<MoodEntry> _moodHistory = ProgressService.cachedMoodHistory ?? [];
  CommunityPost? _latestPost = (CommunityService.cachedPosts ?? []).isNotEmpty ? CommunityService.cachedPosts!.first : null;
  SupportGroup? _upcomingSessionGroup;
  Map<String, dynamic>? _currentSession = SupportGroupService.cachedCurrentSession;
  
  Duration _cleanDuration = Duration.zero;
  Timer? _streakTimer;
  bool _hasShownAssessmentPrompt = false;
  final CommunityService _communityService = CommunityService();

  // Pull-down-and-hold state
  double _pullDownDistance = 0.0;
  double _swipeUpDistance = 0.0;
  bool _isTransitioning = false;
  static const double _pullThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Initialize streak duration if profile is already available
    if (_profile?.cleanDate != null) {
      try {
        final cleanDate = DateTime.parse(_profile!.cleanDate!);
        _cleanDuration = DateTime.now().difference(cleanDate);
      } catch (e) {
        debugPrint("Error parsing clean date: $e");
      }
    } else if (_profile != null) {
      _cleanDuration = Duration(days: _profile!.cleanDays);
    }

    _streakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_profile?.cleanDate != null) {
        try {
          final cleanDate = DateTime.parse(_profile!.cleanDate!);
          setState(() {
            _cleanDuration = DateTime.now().difference(cleanDate);
          });
        } catch (e) {
          debugPrint("Error in streak timer: $e");
        }
      } else if (_profile != null) {
        // Fallback to cleanDays if cleanDate is not set
        setState(() {
          _cleanDuration = Duration(days: _profile!.cleanDays);
        });
      }
    });
  }

  @override
  void dispose() {
    _streakTimer?.cancel();
    super.dispose();
  }

  List<dynamic> _enrollments = RecoveryService.cachedEnrollments ?? [];
  Map<String, dynamic>? _dashboardData = RecoveryService.cachedDashboardData;
  Map<String, dynamic>? _dailyContent = RecoveryService.cachedDailyLearningSummary;

  // ... (existing methods)

  Future<void> _loadData() async {
    try {
      final profile = await ProfileService.getProfile();
      final quote = await RecoveryService.getDailyQuote();
      final moodHistory = await ProgressService.getMoodHistory();
      final posts = await _communityService.getPosts();
      final enrollments = await RecoveryService.getUserEnrollments();
      final dashboardData = await RecoveryService.getProgressDashboard();
      
      Map<String, dynamic>? currentSession;
      try {
        currentSession = await SupportGroupService.getCurrentSession();
      } catch (e) {
        debugPrint("Error loading current session: $e");
      }

      SupportGroup? upcomingSession;
      try {
        final groups = await SupportGroupService.getGroups();
        final myGroups = groups.where((g) => g.isMember).toList();
        if (myGroups.isNotEmpty) {
          myGroups.sort((a, b) => a.getNextSessionDate().compareTo(b.getNextSessionDate()));
          final next = myGroups.first;
          final nextDate = next.getNextSessionDate();
          final now = DateTime.now();
          // If session is today or tomorrow (within 36 hours)
          if (nextDate.difference(now).inHours <= 36) {
            upcomingSession = next;
          }
        }
      } catch (e) {
        debugPrint("Error loading support groups for home: $e");
      }

      Map<String, dynamic>? dailyContent;
      try {
        dailyContent = await RecoveryService.getDailyLearningSummary();
      } catch (e) {
        debugPrint("Error loading daily content: $e");
      }
      
      if (mounted) {
        final communityController = Provider.of<CommunityController>(context, listen: false);
        await communityController.fetchProgramDetails();
        
        setState(() {
          _profile = profile;
          _quote = quote;
          _moodHistory = moodHistory;
          _enrollments = enrollments;
          _dashboardData = dashboardData;
          _dailyContent = dailyContent;
          _upcomingSessionGroup = upcomingSession;
          _currentSession = currentSession;
          
          // Determine current group for pulse
          final statusType = _dashboardData?['current_status_type'];
          final statusId = _dashboardData?['current_status_id'];
          final statusLabel = _dashboardData?['current_status'] ?? "Community";

          // Fetch filtered posts for the pulse
          _fetchFilteredPulsePosts(statusType, statusId);

          _isLoading = false;
        });

        // Show assessment prompt if pending assessments exist and haven't been shown yet
        if (_dashboardData?['pending_assessments'] != null && 
            (_dashboardData?['pending_assessments'] as List).isNotEmpty &&
            !_hasShownAssessmentPrompt) {
          _hasShownAssessmentPrompt = true;
          Future.delayed(const Duration(seconds: 1), () => _showAssessmentPrompt());
        }
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fetchFilteredPulsePosts(String? type, dynamic id) async {
    try {
      List<CommunityPost> filteredPosts = [];
      if (type == 'level' && id != null) {
        filteredPosts = await _communityService.getPosts(levelId: id);
      } else if (type == 'challenge' && id != null) {
        filteredPosts = await _communityService.getPosts(challengeId: id);
      } else {
        filteredPosts = await _communityService.getPosts();
      }

      if (mounted && filteredPosts.isNotEmpty) {
        setState(() {
          _latestPost = filteredPosts.first;
        });
      }
    } catch (e) {
      debugPrint("Error fetching pulse posts: $e");
    }
  }

  void _showAssessmentPrompt() {
    if (!mounted) return;
    final assessments = _dashboardData?['pending_assessments'] as List;
    if (assessments.isEmpty) return;
    final assessment = assessments.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AssessmentPromptSheet(
        assessment: assessment,
        onStart: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AssessmentDetailScreen(assessmentId: assessment['id'])),
          ).then((_) => _loadData());
        },
      ),
    );
  }

  // ... (build methods)

  @override
  Widget build(BuildContext context) {
    // Show loading screen on first use when no cached data is available
    if (_isLoading && _profile == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Loading your dashboard...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return VisibilityDetector(
      key: const Key('home-tab-visibility'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          _loadData();
        }
      },
      child: PageView(
        controller: widget.pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildMinimalView(),
          _buildDashboardView(),
        ],
      ),
    );
  }

  Widget _buildMinimalView() {
    final days = _cleanDuration.inDays;
    final hours = _cleanDuration.inHours % 24;
    final minutes = _cleanDuration.inMinutes % 60;
    final seconds = _cleanDuration.inSeconds % 60;

    return SizedBox.expand(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 1),
                Text(
                  "Welcome back,",
                  style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 22
                  ),
                ),
                Text(
                  _profile?.user.username ?? "User",
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 40), // Slightly reduced from 60

                // Streak Section
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      _buildTimeUnit(days, "DAYS"),
                      _buildSeparator(),
                      _buildTimeUnit(hours, "HRS"),
                      _buildSeparator(),
                      _buildTimeUnit(minutes, "MIN"),
                      _buildSeparator(),
                      _buildTimeUnit(seconds, "SEC"),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "CLEAN STREAK",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 80), // Increased to lower the quote card

                if (_quote != null)
                  DailyInspirationCard(
                    content: _quote!['content'],
                    author: _quote!['author'],
                  ),

                const Spacer(flex: 2), // Reduced to allow quote to sit lower
                const SizedBox(height: 80), // Safe gap for the Relapse Button
              ],
            ),
          ),

          // Relapse Button Positioned at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Center(
              child: RelapseButton(
                onRelapseLogged: () {
                  _loadData();
                  // Reset timer immediately for visual feedback
                  setState(() {
                    _cleanDuration = Duration.zero;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(int value, String label) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: GoogleFonts.outfit(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        ":",
        style: GoogleFonts.outfit(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          color: Colors.white38,
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    final currentStatus = _dashboardData?['current_status'] ?? 'Loading...';
    final statusType = _dashboardData?['current_status_type'] ?? 'unknown';
    final relapseTrend = _dashboardData?['relapse_trend'] as List<dynamic>? ?? [];

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification && 
                notification.direction == ScrollDirection.idle && 
                !_isTransitioning) {
              // User released finger, reset pull distance immediately
              setState(() {
                _pullDownDistance = 0;
              });
            } else if (notification is ScrollUpdateNotification) {
              if (notification.metrics.pixels < 0) {
                setState(() {
                  _pullDownDistance = -notification.metrics.pixels;
                });

                if (_pullDownDistance >= _pullThreshold && !_isTransitioning) {
                  _isTransitioning = true;
                  // Haptic feedback would be good here if available
                  widget.pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutQuart,
                  ).then((_) {
                    setState(() {
                      _pullDownDistance = 0;
                      _isTransitioning = false;
                    });
                  });
                }
              } else if (_pullDownDistance != 0) {
                setState(() {
                  _pullDownDistance = 0;
                });
              }
            } else if (notification is ScrollEndNotification) {
              setState(() {
                _pullDownDistance = 0;
              });
            }
            return false;
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),

                // Tools Hub Access
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pushNamed(context, 'tools_hub_screen');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Immediate Help Tools',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Breathing, grounding, & coping tools',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Challenges Carousel (Active & Unlocked)
                if ((_dashboardData?['active_challenges'] as List? ?? []).isNotEmpty || 

                    (_dashboardData?['available_challenges'] as List? ?? []).isNotEmpty) ...[
                  SizedBox(
                    height: 220,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        ...(_dashboardData?['active_challenges'] as List? ?? []).map((challenge) => SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: ChallengeCard(
                              key: ValueKey('active_challenge_${challenge['id'] ?? challenge['title']}'),
                              challenge: challenge,
                              isActive: true,
                              onTap: () => Navigator.pushNamed(context, ChallengeListScreen.id).then((_) => _loadData()),
                            ),
                          ),
                        )),
                        ...(_dashboardData?['available_challenges'] as List? ?? []).map((challenge) => SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: ChallengeCard(
                              key: ValueKey('avail_challenge_${challenge['id'] ?? challenge['title']}'),
                              challenge: challenge,
                              isActive: false,
                              onTap: () => Navigator.pushNamed(context, ChallengeListScreen.id).then((_) => _loadData()),
                              onActionPressed: () async {
                                await RecoveryService.startChallenge(challenge['id']);
                                _loadData();
                              },
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_currentSession != null)
                  SupportGroupSessionWidget(session: _currentSession!),

                const SizedBox(height: 16),

                // Progress Summary Row
                Row(
                  children: [
                    Expanded(
                      child: ProgressCard(
                        title: 'Current Status',
                        value: statusType == 'level' ? currentStatus.replaceAll('Level ', '') : (statusType == 'assessment' ? 'Test' : 'Active'),
                        subtitle: statusType == 'level' ? 'Level' : (statusType == 'challenge' ? 'Challenge' : (statusType == 'assessment' ? 'Assessment' : 'Status')),
                        icon: statusType == 'challenge' ? Icons.flag : (statusType == 'assessment' ? Icons.assignment : Icons.layers),
                        color: Colors.blueAccent,
                        onTap: () {
                          // Navigate based on status
                          if (statusType == 'level' && _enrollments.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LevelListScreen(programId: _enrollments.first['program']),
                              ),
                            ).then((_) => _loadData());
                          } else if (statusType == 'challenge') {
                            Navigator.pushNamed(context, ChallengeListScreen.id).then((_) => _loadData());
                          } else if (statusType == 'assessment' && _dashboardData?['current_status_id'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AssessmentDetailScreen(assessmentId: _dashboardData!['current_status_id']),
                              ),
                            ).then((_) => _loadData());
                          } else {
                            _navigateToProgress(context);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ProgressCard(
                        title: 'Streak',
                        value: '${_profile?.cleanDays ?? 0}',
                        subtitle: 'Days',
                        icon: Icons.local_fire_department,
                        color: Colors.orangeAccent,
                        onTap: () => _navigateToProgress(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ProgressCard(
                        title: 'Mood',
                        value: 'Log',
                        subtitle: 'Check-in',
                        icon: Icons.mood,
                        color: Colors.purpleAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MoodCheckinScreen()),
                          ).then((_) => setState(() { _loadData(); }));
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ProgressCard(
                        title: 'Relapses',
                        value: 'Log',
                        subtitle: 'Track',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RelapseLogScreen()),
                          ).then((_) => setState(() { _loadData(); }));
                        },
                      ),
                    ),
                  ],
                ),

                if (_dashboardData != null && _dashboardData!['active_program'] != null) ...[
                  const SizedBox(height: 30),
                  CurrentProgramCard(
                    activeProgram: _dashboardData!['active_program'],
                    onOpenProgram: () {
                      final programId = _dashboardData!['active_program']['id'];
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LevelListScreen(programId: programId)),
                      ).then((_) => _loadData());
                    },
                    onSwitchProgram: () async {
                      try {
                        final programs = await RecoveryService.getPrograms();
                        if (mounted) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => DraggableScrollableSheet(
                              initialChildSize: 0.7,
                              minChildSize: 0.5,
                              maxChildSize: 0.9,
                              builder: (_, scrollController) => ProgramSwitcherSheet(
                                allPrograms: programs,
                                activeProgramId: _dashboardData!['active_program']['id'],
                                onProgramSwitched: (newProgramId) async {
                                  await RecoveryService.switchProgram(newProgramId);
                                  _loadData(); // Reload everything
                                },
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading programs: $e')));
                      }
                    },
                  ),
                ],

                if (_dashboardData?['pending_assessments'] != null && 
                    (_dashboardData?['pending_assessments'] as List).isNotEmpty) ...[
                  const SizedBox(height: 30),
                  ...(_dashboardData?['pending_assessments'] as List).map((assessment) => PendingAssessmentCard(
                    assessment: assessment,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AssessmentDetailScreen(assessmentId: assessment['id'])),
                      ).then((_) => _loadData());
                    },
                  )),
                ],

                if (_upcomingSessionGroup != null) ...[
                  const SizedBox(height: 30),
                  _buildUpcomingSessionCard(),
                ],

                if (relapseTrend.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: const RelapseTrendChart(),
                  ),
                ],

                if (_dailyContent != null && (_dailyContent!['content'] as List).isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, color: Theme.of(context).primaryColor, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Today\'s Learning',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(_dailyContent!['spent_seconds'] as int) ~/ 60} / ${_dailyContent!['daily_limit_minutes']} min',
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 12,
                            child: LinearProgressIndicator(
                              value: ((_dailyContent!['spent_seconds'] as int) / 60 / (_dailyContent!['daily_limit_minutes'] as int)).clamp(0.0, 1.0),
                              backgroundColor: Colors.black26,
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                            ),
                          ),
                        ),
                        if (((_dailyContent!['spent_seconds'] as int) / 60) >= (_dailyContent!['daily_limit_minutes'] as int))
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Daily goal reached! You can keep going.',
                                  style: GoogleFonts.outfit(color: Colors.greenAccent.shade400, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...(_dailyContent!['content'] as List).map((media) => Padding(
                    key: ValueKey('media_${media['id'] ?? media['title']}'),
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ActionTile(
                      title: media['title'],
                      subtitle: "${media['media_type'].toString().toUpperCase()} • ${media['estimated_duration']} MIN",
                      icon: Icons.play_lesson_rounded,
                      color: Colors.indigo,
                      onTap: () {
                         final currentLevel = _dailyContent!['current_level'];
                         if (currentLevel != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => LevelDetailScreen(
                                levelId: currentLevel['id'],
                            ))).then((_) => _loadData());
                         }
                      },
                    ),
                  )),
                ],

                Consumer<CommunityController>(
                  builder: (context, communityController, child) {
                    final String groupName;
                    if (communityController.primaryChallengeTitle != null) {
                      groupName = communityController.primaryChallengeTitle!;
                    } else if (communityController.assignedLevelTitle != null) {
                      groupName = communityController.assignedLevelTitle!;
                    } else {
                      groupName = _dashboardData?['current_status'] ?? "Community";
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 30),
                        CommunityPulseCarousel(
                          groupName: groupName,
                          latestPost: communityController.posts.isNotEmpty ? communityController.posts.first : null,
                          onTap: () {
                            final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                            if (homeState != null) {
                              homeState._onItemTapped(1); // Index 1 is Community tab
                            }
                          },
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 30),

                // Quick Actions
                Text(
                  'Quick Access',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ActionTile(
                  title: 'Challenges',
                  subtitle: 'View your challenges',
                  icon: Icons.check_circle_rounded,
                  color: Colors.purpleAccent,
                  onTap: () {
                    Navigator.pushNamed(context, ChallengeListScreen.id).then((_) => _loadData());
                  },
                ),

                const SizedBox(height: 12),
                ActionTile(
                  title: 'Self-Assessments',
                  subtitle: 'Check your mental well-being',
                  icon: Icons.assignment_turned_in_rounded,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssessmentListScreen()),
                    ).then((_) => _loadData());
                  },
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // Pull-to-return indicator
        if (_pullDownDistance > 10)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: (_pullDownDistance / _pullThreshold).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _pullDownDistance >= _pullThreshold
                          ? Colors.blueAccent
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _pullDownDistance >= _pullThreshold
                            ? Icons.check_circle_outline
                            : Icons.arrow_downward_rounded,
                        color: _pullDownDistance >= _pullThreshold
                            ? Colors.blueAccent
                            : Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _pullDownDistance >= _pullThreshold
                            ? "Release to return"
                            : "Pull down to return",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToProgress(BuildContext context) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeState != null) {
      homeState._onItemTapped(3); // Index 3 is Progress tab
    }
  }

  Widget _buildUpcomingSessionCard() {
    final sessionDate = _upcomingSessionGroup!.getNextSessionDate();
    final isToday = sessionDate.day == DateTime.now().day;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withOpacity(0.2), Colors.indigo.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.video_call_rounded, color: Colors.blueAccent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday ? 'Session Today' : 'Upcoming Session',
                        style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Text(
                        _upcomingSessionGroup!.title,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Starts at ${_upcomingSessionGroup!.weeklyStartTime}',
                        style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    if (homeState != null) {
                      homeState._onItemTapped(2); // Index 2 is Therapy tab
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('VIEW', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class RelapseButton extends StatefulWidget {
  final VoidCallback? onRelapseLogged;
  const RelapseButton({super.key, this.onRelapseLogged});

  @override
  State<RelapseButton> createState() => _RelapseButtonState();
}

class _RelapseButtonState extends State<RelapseButton> {
  bool _isExpanded = false;
  bool _isRecording = false;
  bool _isCancelled = false;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      // Auto-collapse when focus is lost (user tapped elsewhere)
      if (!_focusNode.hasFocus && _isExpanded && !_isRecording) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (!_isRecording) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
      if (_isExpanded) {
        // Request focus when expanding
        Future.delayed(const Duration(milliseconds: 350), () {
          _focusNode.requestFocus();
        });
      }
    }
  }

  Future<void> _handleLongPressStart(LongPressStartDetails details) async {
    if (!_isExpanded) {
      // Check permissions
      if (await Permission.microphone.request().isGranted) {
        setState(() {
          _isRecording = true;
          _isCancelled = false;
          _recordingDuration = 0;
        });
        
        _startTimer();

        // Start recording
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/relapse_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        if (await _audioRecorder.hasPermission()) {
          await _audioRecorder.start(const RecordConfig(), path: path);
          _audioPath = path;
        }
      }
    }
  }

  void _startTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_isRecording) {
      // If dragged significantly to the left, mark as cancelled
      if (details.offsetFromOrigin.dx < -50) {
        if (!_isCancelled) {
          setState(() => _isCancelled = true);
        }
      } else {
        if (_isCancelled) {
          setState(() => _isCancelled = false);
        }
      }
    }
  }

  Future<void> _handleLongPressEnd(LongPressEndDetails details) async {
    if (_isRecording) {
      _recordingTimer?.cancel();
      
      // Stop recording
      final path = await _audioRecorder.stop();
      
      if (_isCancelled) {
        // Delete file if cancelled
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Recording cancelled")),
          );
        }
      } else {
        // Submit if not cancelled
        if (path != null) {
          _submitRelapse("Audio Log", audioPath: path);
        }
      }

      setState(() {
        _isRecording = false;
        _isCancelled = false;
        _recordingDuration = 0;
      });
    }
  }

  Future<void> _submitRelapse(String cause, {String? audioPath}) async {
    try {
      final entry = RelapseEntry(
        date: DateTime.now().toIso8601String(),
        cause: cause.isEmpty ? null : cause,
        emotions: null, // Optional
        notes: audioPath != null ? "Audio recording logged" : "Quick log from home screen",
        audioPath: audioPath,
      );

      await ProgressService.logRelapse(entry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(audioPath != null ? "Audio logged" : "Relapse logged"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isExpanded = false;
          _textController.clear();
        });
        widget.onRelapseLogged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error logging relapse: $e")),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: (d) => _handleLongPressStart(d),
      onLongPressMoveUpdate: (d) => _handleLongPressMoveUpdate(d),
      onLongPressEnd: (d) => _handleLongPressEnd(d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: _isExpanded ? MediaQuery.of(context).size.width * 0.8 : 80,
        height: _isExpanded ? 56 : 80,
        child: _isExpanded
            ? Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          autofocus: false,
                          style: GoogleFonts.outfit(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "What happened?",
                            hintStyle: GoogleFonts.outfit(color: Colors.white54),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onSubmitted: (value) => _submitRelapse(value),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.redAccent, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _submitRelapse(_textController.text),
                      ),
                    ],
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isCancelled
                        ? Colors.grey.withOpacity(0.3)
                        : Colors.redAccent.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isRecording
                            ? (_isCancelled ? "Cancel" : "Rec...")
                            : "Relapse",
                        style: GoogleFonts.outfit(
                          color: _isCancelled ? Colors.grey : Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      if (_isRecording && !_isCancelled)
                        Text(
                          _formatDuration(_recordingDuration),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}




