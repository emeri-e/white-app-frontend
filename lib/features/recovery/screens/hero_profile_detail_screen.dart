import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/recovery/services/hero_service.dart';

class HeroProfileDetailScreen extends StatefulWidget {
  static const String id = 'hero_profile_detail_screen';
  final int heroId;
  final bool startAtVod;

  const HeroProfileDetailScreen({
    super.key,
    required this.heroId,
    this.startAtVod = false,
  });

  @override
  State<HeroProfileDetailScreen> createState() => _HeroProfileDetailScreenState();
}

class _HeroProfileDetailScreenState extends State<HeroProfileDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _hero;
  List<dynamic> _comments = [];
  bool _isLiked = false;
  bool _isLoved = false;
  int _likesCount = 0;
  int _lovesCount = 0;

  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _stateTimer;

  // Broadcast Panel State
  // "pre_live", "live", "post_live"
  String _broadcastState = "pre_live"; 
  Duration _countdownDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadHeroDetails();
    _stateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateBroadcastState();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _stateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHeroDetails() async {
    setState(() => _isLoading = true);
    try {
      // Find the hero profile from the list of published heroes
      final heroes = await HeroService.getPublishedHeroes();
      final hero = heroes.firstWhere((h) => h['id'] == widget.heroId, orElse: () => null);

      if (hero != null) {
        final comments = await HeroService.getComments(widget.heroId);
        setState(() {
          _hero = hero;
          _comments = comments;
          _likesCount = hero['likes_count'] ?? 0;
          _lovesCount = hero['loves_count'] ?? 0;
          _isLiked = hero['is_liked'] ?? false;
          _isLoved = hero['is_loved'] ?? false;
          _isLoading = false;
        });
        _updateBroadcastState();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading hero details: $e");
      setState(() => _isLoading = false);
    }
  }

  void _updateBroadcastState() {
    if (_hero == null) return;

    final events = _hero!['events'] as List<dynamic>? ?? [];
    if (events.isEmpty) {
      setState(() {
        _broadcastState = "pre_live";
      });
      return;
    }

    final event = events.first; // Latest scheduling
    final scheduledTime = DateTime.parse(event['scheduled_time']);
    final durationMins = event['duration_minutes'] ?? 60;
    final endTime = scheduledTime.add(Duration(minutes: durationMins));
    final now = DateTime.now();

    if (widget.startAtVod || event['vod_url'] != null && event['vod_url'].toString().isNotEmpty && now.isAfter(endTime)) {
      setState(() {
        _broadcastState = "post_live";
      });
    } else if (now.isAfter(scheduledTime) && now.isBefore(endTime)) {
      setState(() {
        _broadcastState = "live";
      });
    } else {
      setState(() {
        _broadcastState = "pre_live";
        _countdownDuration = scheduledTime.difference(now);
      });
    }
  }

  Future<void> _toggleReaction(String reactionType) async {
    if (_hero == null) return;
    
    final currentActive = reactionType == 'like' ? _isLiked : _isLoved;
    setState(() {
      if (reactionType == 'like') {
        _isLiked = !currentActive;
        _likesCount += _isLiked ? 1 : -1;
      } else {
        _isLoved = !currentActive;
        _lovesCount += _isLoved ? 1 : -1;
      }
    });

    try {
      await HeroService.reactToHero(widget.heroId, reactionType, !currentActive);
    } catch (e) {
      debugPrint("Error toggling reaction: $e");
      // Revert local state
      setState(() {
        if (reactionType == 'like') {
          _isLiked = currentActive;
          _likesCount += _isLiked ? 1 : -1;
        } else {
          _isLoved = currentActive;
          _lovesCount += _isLoved ? 1 : -1;
        }
      });
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus();

    try {
      final newComment = await HeroService.postComment(widget.heroId, text);
      setState(() {
        // Prepend comment for immediate feedback
        _comments.insert(0, newComment);
      });
      // Scroll to top of comment list
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.indigo)),
      );
    }

    if (_hero == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hero Profile')),
        body: const Center(child: Text('Profile not found.')),
      );
    }

    final alias = _hero!['alias'] ?? 'Anonymous Hero';
    final cleanDays = _hero!['clean_days'] ?? 180;
    final category = _hero!['program_category'] ?? 'recovery';
    final story = _hero!['story_summary'] ?? '';

    return Scaffold(
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      '$alias Journey',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Match back button size
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Broadcast Stage Container
                      _buildBroadcastStage(),
                      const SizedBox(height: 24),

                      // Profile Info & Clean Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alias,
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                category.toString().toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$cleanDays DAYS CLEAN',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Story Body
                      Text(
                        story,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reaction buttons
                      Row(
                        children: [
                          _buildReactionButton(
                            icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            label: 'Like ($_likesCount)',
                            color: Colors.pinkAccent,
                            isActive: _isLiked,
                            onTap: () => _toggleReaction('like'),
                          ),
                          const SizedBox(width: 12),
                          _buildReactionButton(
                            icon: _isLoved ? Icons.star_rounded : Icons.star_outline_rounded,
                            label: 'Love ($_lovesCount)',
                            color: Colors.amberAccent,
                            isActive: _isLoved,
                            onTap: () => _toggleReaction('love'),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 40),

                      // Community Wall title
                      Text(
                        'Community Support Wall',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Comment Textfield
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Write an encouraging comment...',
                                hintStyle: const TextStyle(color: Colors.white30),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                            onPressed: _postComment,
                          )
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Comments List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final author = comment['user_name'] ?? 'User';
                          final text = comment['comment_text'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  author,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.white24,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? color : Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isActive ? color : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastStage() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildStageContent(),
      ),
    );
  }

  Widget _buildStageContent() {
    if (_broadcastState == "pre_live") {
      final days = _countdownDuration.inDays;
      final hrs = _countdownDuration.inHours % 24;
      final mins = _countdownDuration.inMinutes % 60;
      final secs = _countdownDuration.inSeconds % 60;

      final countdownStr = days > 0
          ? '${days}d ${hrs}h ${mins}m'
          : '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

      return Stack(
        fit: StackFit.expand,
        children: [
          // Blur background simulation
          Container(
            color: Colors.indigo.withOpacity(0.2),
            child: const Center(
              child: Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 48),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Live session broadcast scheduled',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  countdownStr,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.black,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          )
        ],
      );
    } else if (_broadcastState == "live") {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Live Video Container
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.live_tv_rounded, color: Colors.redAccent, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'Live co-hosted session broadcast active',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          // "Live" Indicator Tag
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // VOD Player State
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
                  SizedBox(height: 8),
                  Text(
                    'Watch recovery milestone archive (VOD)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ARCHIVE',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          )
        ],
      );
    }
  }
}
