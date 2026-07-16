import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/recovery/services/hero_service.dart';
import 'package:whiteapp/features/recovery/screens/hero_profile_detail_screen.dart';

class WhiteHeroesHubScreen extends StatefulWidget {
  static const String id = 'white_heroes_hub_screen';

  const WhiteHeroesHubScreen({super.key});

  @override
  State<WhiteHeroesHubScreen> createState() => _WhiteHeroesHubScreenState();
}

class _WhiteHeroesHubScreenState extends State<WhiteHeroesHubScreen> {
  bool _isLoading = true;
  String _selectedCategory = 'all';
  List<dynamic> _allHeroes = [];
  List<dynamic> _upcomingEvents = [];
  List<dynamic> _vods = [];
  Set<int> _reminderSet = {};

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Trigger update for active countdowns
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final heroes = await HeroService.getPublishedHeroes(category: _selectedCategory);
      final upcoming = await HeroService.getUpcomingEvents();
      final vodList = await HeroService.getVods();

      setState(() {
        _allHeroes = heroes;
        _upcomingEvents = upcoming;
        _vods = vodList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading heroes hub: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleReminder(int eventId) async {
    final isAdding = !_reminderSet.contains(eventId);
    try {
      await HeroService.toggleReminder(eventId);
      setState(() {
        if (isAdding) {
          _reminderSet.add(eventId);
        } else {
          _reminderSet.remove(eventId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdding ? 'Reminder activated!' : 'Reminder removed.'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    } catch (e) {
      debugPrint("Error toggling reminder: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter heroes by category locally just in case
    final filteredHeroes = _selectedCategory == 'all'
        ? _allHeroes
        : _allHeroes
            .where((h) => h['program_category']?.toString().toLowerCase() == _selectedCategory.toLowerCase())
            .toList();

    return Scaffold(
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            color: Theme.of(context).primaryColor,
            backgroundColor: const Color(0xFF1E293B),
            child: CustomScrollView(
              slivers: [
                // Top AppBar
                SliverAppBar(
                  expandedHeight: 80,
                  pinned: true,
                  backgroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'White Heroes Hub',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    centerTitle: true,
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Upcoming Live Events Carousel Header
                if (_upcomingEvents.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Text(
                        'Upcoming Live Broadcasts',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: PageView.builder(
                        itemCount: _upcomingEvents.length,
                        controller: PageController(viewportFraction: 0.85),
                        itemBuilder: (context, index) {
                          final event = _upcomingEvents[index];
                          final scheduledTime = DateTime.parse(event['scheduled_time']);
                          final duration = scheduledTime.difference(DateTime.now());
                          final isBellActive = _reminderSet.contains(event['id']);

                          // Format countdown string
                          String countdownStr;
                          if (duration.isNegative) {
                            countdownStr = "Live Now!";
                          } else {
                            final days = duration.inDays;
                            final hrs = duration.inHours % 24;
                            final mins = duration.inMinutes % 60;
                            final secs = duration.inSeconds % 60;
                            countdownStr = days > 0
                                ? '${days}d ${hrs}h ${mins}m'
                                : '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black38,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          event['program_category']?.toString().toUpperCase() ?? 'RECOVERY',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          isBellActive
                                              ? Icons.notifications_active_rounded
                                              : Icons.notifications_none_rounded,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => _toggleReminder(event['id']),
                                      )
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    event['hero_alias'] ?? 'Guest Hero',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Starts in: $countdownStr',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white90,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Category Filter Tabs
                SliverToBoxAdapter(
                  child: Padding(
                    key: const ValueKey('category_pills'),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: ['all', 'pornography', 'drugs', 'depression', 'anxiety'].map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: ChoiceChip(
                              label: Text(cat == 'all' ? 'All Stories' : cat.toUpperCase()),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategory = cat;
                                  });
                                  _loadAllData();
                                }
                              },
                              selectedColor: Theme.of(context).primaryColor,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              backgroundColor: Colors.white.withOpacity(0.05),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Hero Cards List
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Text(
                      'Published Stories',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: Colors.indigo)),
                  )
                else if (filteredHeroes.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No recovery stories listed in this category yet.',
                          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final hero = filteredHeroes[index];
                        final alias = hero['alias'] ?? 'Anonymous Hero';
                        final cleanDays = hero['clean_days'] ?? 180;
                        final category = hero['program_category'] ?? 'recovery';
                        final storySnippet = hero['story_summary'] ?? '';

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HeroProfileDetailScreen(heroId: hero['id']),
                                ),
                              ).then((_) => _loadAllData());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.star_rounded, color: Theme.of(context).primaryColor, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              alias,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              category.toString().toUpperCase(),
                                              style: GoogleFonts.outfit(
                                                color: Colors.white54,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$cleanDays DAYS CLEAN',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    storySnippet,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Read Full Story →',
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filteredHeroes.length,
                    ),
                  ),

                // VOD Archives
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0, bottom: 12.0),
                    child: Text(
                      'Video Archives (VOD)',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                if (_vods.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No VOD videos recorded yet.',
                          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    key: const ValueKey('vod_grid'),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final vod = _vods[index];
                          final alias = vod['hero_alias'] ?? 'Guest Hero';
                          final duration = vod['duration_minutes'] ?? 60;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HeroProfileDetailScreen(
                                      heroId: vod['hero_id'],
                                      startAtVod: true,
                                    ),
                                  ),
                                );
                              },
                              child: Stack(
                                children: [
                                  // Mock thumbnail container
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Colors.black45,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  ),
                                  // Details Overlay
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$alias Journey',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Duration: $duration mins',
                                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _vods.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 48),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
