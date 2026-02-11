import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
import 'package:whiteapp/features/profile/models/user_profile.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/features/recovery/screens/program_list_screen.dart';
import 'package:whiteapp/features/recovery/screens/challenge_list_screen.dart';
import 'package:whiteapp/features/recovery/screens/level_list_screen.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:whiteapp/features/community/screens/community_feed_screen.dart';
import 'package:whiteapp/features/support_groups/screens/support_group_list_screen.dart';
import 'package:whiteapp/features/profile/screens/profile_screen.dart';
import 'package:whiteapp/features/progress/screens/progress_screen.dart';

import 'package:whiteapp/features/progress/screens/mood_checkin_screen.dart';
import 'package:whiteapp/features/progress/screens/relapse_log_screen.dart';
import 'package:whiteapp/features/assessments/screens/assessment_list_screen.dart';
import 'package:whiteapp/features/home/widgets/home_widgets.dart';
import 'package:whiteapp/core/services/community_service.dart';
import 'package:whiteapp/features/community/models/community_post.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/features/progress/models/mood_entry.dart';
import 'package:whiteapp/features/progress/models/relapse_entry.dart';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';

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

  @override
  Widget build(BuildContext context) {
    // If we are not on Home tab, we treat it as "Dashboard" view (progress 1.0)
    // or keep the background static at 1.0
    final effectiveProgress = _selectedIndex == 0 ? _scrollProgress : 1.0;

    return Scaffold(
      extendBody: true, // Allows background to extend behind the nav bar
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
  UserProfile? _profile;
  Map<String, dynamic>? _quote;
  List<MoodEntry> _moodHistory = [];
  CommunityPost? _latestPost;
  bool _isLoading = true;
  final CommunityService _communityService = CommunityService();
  Timer? _timer;
  Duration _cleanDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_profile?.cleanDate != null) {
        final cleanDate = DateTime.parse(_profile!.cleanDate!);
        setState(() {
          _cleanDuration = DateTime.now().difference(cleanDate);
        });
      } else if (_profile != null) {
        // Fallback to cleanDays if cleanDate is not set
        setState(() {
          _cleanDuration = Duration(days: _profile!.cleanDays);
        });
      }
    });
  }

  List<dynamic> _enrollments = [];

  Map<String, dynamic>? _dashboardData;

  // ... (existing methods)

  Future<void> _loadData() async {
    try {
      final profile = await ProfileService.getProfile();
      final quote = await RecoveryService.getDailyQuote();
      final moodHistory = await ProgressService.getMoodHistory();
      final posts = await _communityService.getPosts();
      final enrollments = await RecoveryService.getUserEnrollments();
      final dashboardData = await RecoveryService.getProgressDashboard();
      
      if (mounted) {
        setState(() {
          _profile = profile;
          _quote = quote;
          _moodHistory = moodHistory;
          _enrollments = enrollments;
          _dashboardData = dashboardData;
          if (posts.isNotEmpty) {
            _latestPost = posts.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading home data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (build methods)

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView(
      controller: widget.pageController,
      scrollDirection: Axis.vertical,
      children: [
        _buildMinimalView(),
        _buildDashboardView(),
      ],
    );
  }

  Widget _buildMinimalView() {
    final days = _cleanDuration.inDays;
    final hours = _cleanDuration.inHours % 24;
    final minutes = _cleanDuration.inMinutes % 60;
    final seconds = _cleanDuration.inSeconds % 60;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
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
              const SizedBox(height: 60),
              
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
              
              const Spacer(flex: 1),
              
              if (_quote != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: DailyInspirationCard(
                    content: _quote!['content'],
                    author: _quote!['author'],
                  ),
                ),
                
              const Spacer(flex: 2),
            ],
          ),
        ),
        
        // Relapse Button Positioned to overlap background circles
        // Assuming background circles are centered or slightly offset
        // Based on AbstractBackground logic, the target is around height * 0.75
        // We want to position this button there.
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.of(context).size.height * 0.85 - 30, // Centered on the target Y
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

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification) {
          // If overscrolling at the top (dragging down), go to minimal view
          if (notification.overscroll < 0 && notification.metrics.pixels <= 0) {
            widget.pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
        return false;
      },
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),

          // Progress Summary Row
          Row(
            children: [
              Expanded(
                child: ProgressCard(
                  title: 'Current Status',
                  value: statusType == 'level' ? currentStatus.replaceAll('Level ', '') : 'Active',
                  subtitle: statusType == 'level' ? 'Level' : (statusType == 'challenge' ? 'Challenge' : 'Status'),
                  icon: statusType == 'challenge' ? Icons.flag : Icons.layers,
                  color: Colors.blueAccent,
                  onTap: () {
                     // Navigate based on status
                     if (statusType == 'level' && _enrollments.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LevelListScreen(programId: _enrollments.first['program']),
                          ),
                        );
                     } else if (statusType == 'challenge') {
                        Navigator.pushNamed(context, ChallengeListScreen.id);
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
          
          if (relapseTrend.isNotEmpty) ...[
            const SizedBox(height: 30),
            Text(
              'Relapse Trend (Last 7 Days)',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: RelapseTrendChart(),
            ),
          ],

          if (_latestPost != null) ...[
            const SizedBox(height: 30),
            CommunityPulseWidget(
              title: _latestPost!.authorName,
              content: _latestPost!.displayText,
              likes: _latestPost!.reactionsCount,
              comments: _latestPost!.commentsCount,
              onTap: () {
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                if (homeState != null) {
                  homeState._onItemTapped(1); // Index 1 is Community tab
                }
              },
            ),
          ],
          const SizedBox(height: 30),

          // Quick Actions
          Text(
            'Quick Actions',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ActionTile(
            title: 'Continue Learning',
            subtitle: _enrollments.isNotEmpty 
                ? 'Resume ${_enrollments.first['program_title'] ?? 'Program'}' 
                : 'Start a program',
            icon: Icons.play_circle_fill_rounded,
            color: Colors.blueAccent,
            onTap: () {
              if (_enrollments.isNotEmpty) {
                final programId = _enrollments.first['program'];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LevelListScreen(programId: programId),
                  ),
                );
              } else {
                Navigator.pushNamed(context, ProgramListScreen.id);
              }
            },
          ),
          const SizedBox(height: 12),
          ActionTile(
            title: 'Daily Challenge',
            subtitle: 'Complete today\'s task',
            icon: Icons.check_circle_rounded,
            color: Colors.purpleAccent,
            onTap: () {
              Navigator.pushNamed(context, ChallengeListScreen.id);
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
              );
            },
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    ),
    );
  }

  void _navigateToProgress(BuildContext context) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeState != null) {
      homeState._onItemTapped(3); // Index 3 is Progress tab
    }
  }
}

class RelapseTrendChart extends StatefulWidget {
  const RelapseTrendChart({Key? key}) : super(key: key);

  @override
  State<RelapseTrendChart> createState() => _RelapseTrendChartState();
}

class _RelapseTrendChartState extends State<RelapseTrendChart> {
  String _selectedRange = '7D'; // 7D, 1M, 1Y
  List<FlSpot> _spots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ProgressService.getRelapseTrend(_selectedRange);
      final spots = <FlSpot>[];
      for (int i = 0; i < data.length; i++) {
        spots.add(FlSpot(i.toDouble(), (data[i]['count'] as int).toDouble()));
      }
      if (mounted) {
        setState(() {
          _spots = spots;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Handle error silently or show snackbar
      }
    }
  }

  void _onRangeSelected(String range) {
    if (_selectedRange != range) {
      setState(() => _selectedRange = range);
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildRangeButton('7D'),
              const SizedBox(width: 8),
              _buildRangeButton('1M'),
              const SizedBox(width: 8),
              _buildRangeButton('1Y'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _spots,
                          isCurved: true,
                          color: Colors.redAccent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.redAccent.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String range) {
    final isSelected = _selectedRange == range;
    return GestureDetector(
      onTap: () => _onRangeSelected(range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.redAccent : Colors.white24),
        ),
        child: Text(
          range,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
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
  late AnimationController _animationController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    // _animationController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(seconds: 4),
    // )..repeat();
  }

  @override
  void dispose() {
    // _animationController.dispose();
    _textController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (!_isRecording) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
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
        width: _isExpanded ? MediaQuery.of(context).size.width * 0.8 : 120,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Wavy Background
            // Static Background
            if (!_isExpanded)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isCancelled ? Colors.grey.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),

            // Content
            _isExpanded
                ? Container(
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
                            autofocus: true,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "What happened?",
                              hintStyle: GoogleFonts.outfit(color: Colors.white54),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (value) => _submitRelapse(value),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.redAccent),
                          onPressed: () => _submitRelapse(_textController.text),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRecording 
                          ? (_isCancelled ? "Release to Cancel" : "Recording...") 
                          : "Relapse",
                        style: GoogleFonts.outfit(
                          color: _isCancelled ? Colors.grey : Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (_isRecording && !_isCancelled)
                        Text(
                          _formatDuration(_recordingDuration),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}




