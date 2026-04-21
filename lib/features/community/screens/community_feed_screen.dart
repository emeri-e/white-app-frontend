import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/features/community/widgets/post_card.dart';
import 'package:whiteapp/features/community/screens/create_post_screen.dart';
import 'package:whiteapp/features/community/screens/moderation_queue_screen.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({Key? key}) : super(key: key);

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CommunityController _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller = Provider.of<CommunityController>(context, listen: false);
    _loadData();
  }

  Future<void> _loadData() async {
    await _controller.fetchProgramDetails();
    await _controller.fetchPosts();
    await _controller.fetchRecoveryStories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 90, // Reduced height since title is gone
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.withOpacity(0.05), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: _loadData,
              ),
              if (ProfileService.cachedProfile?.user.isStaff ?? false)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.orangeAccent),
                  tooltip: 'Moderation Queue',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ModerationQueueScreen()),
                    ).then((_) => _loadData());
                  },
                ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(58), // Increased to 58 for safety and better spacing
              child: Container(
                height: 58,
                padding: const EdgeInsets.only(bottom: 6), // Extra bottom padding for indicator
                decoration: BoxDecoration(
                   color: const Color(0xFF0F172A),
                   border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blueAccent,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white30,
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: const [
                    Tab(text: 'FEED'),
                    Tab(text: 'STORIES'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllPostsTab(),
            _buildRecoveryStoriesTab(),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74), // Elevated to clear the BottomNavigationBar
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreatePostScreen()),
            ).then((_) => _loadData());
          },
          backgroundColor: Colors.blueAccent,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text('Post', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildAllPostsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF1E293B),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildFilterSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          Consumer<CommunityController>(
            builder: (context, controller, child) {
              if (controller.isLoading && controller.posts.isEmpty) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
              }

              if (controller.error != null && controller.posts.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${controller.error}', style: GoogleFonts.outfit(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }

              if (controller.posts.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.white10),
                        const SizedBox(height: 16),
                        Text('No posts in this group yet.', style: GoogleFonts.outfit(color: Colors.white30)),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => PostCard(post: controller.posts[index]),
                  childCount: controller.posts.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildRecoveryStoriesTab() {
    return Consumer<CommunityController>(
      builder: (context, controller, child) {
        if (controller.isLoading && controller.recoveryStories.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }

        if (controller.recoveryStories.isEmpty) {
          return Center(child: Text('No recovery stories yet.', style: GoogleFonts.outfit(color: Colors.white30)));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 100),
          itemCount: controller.recoveryStories.length,
          itemBuilder: (context, index) => PostCard(post: controller.recoveryStories[index]),
        );
      },
    );
  }

  Widget _buildFilterSection() {
    return Consumer<CommunityController>(
      builder: (context, controller, child) {
        if (controller.levels.isEmpty && controller.challenges.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 52, // Fixed height to prevent overflow and ensure consistency
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  selected: controller.selectedLevelId == null && controller.selectedChallengeId == null,
                  onSelected: (val) => _controller.fetchPosts(useDefaults: false),
                ),
                
                // Assigned Level Chip
                if (controller.assignedLevelId != null) ...[
                  _buildFilterChip(
                    label: controller.assignedLevelTitle ?? 'Level ${controller.assignedLevelId}',
                    selected: controller.selectedLevelId == controller.assignedLevelId,
                    onSelected: (val) => _controller.fetchPosts(levelId: controller.assignedLevelId),
                    color: Colors.greenAccent,
                  ),
                ],

                // Assigned Challenge Chips
                ...controller.myGroupChallenges.map((challenge) {
                  final id = challenge['id'] as int;
                  final title = challenge['title'] as String;
                  return _buildFilterChip(
                    label: title,
                    selected: controller.selectedChallengeId == id,
                    onSelected: (val) => _controller.fetchPosts(challengeId: id),
                    color: Colors.orangeAccent,
                  );
                }).toList(),

                // "Others" Button
                _buildFilterChip(
                  label: 'Others',
                  selected: false,
                  onSelected: (val) => _showAllFiltersBottomSheet(context, controller),
                  color: Colors.blueAccent.withOpacity(0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({required String label, required bool selected, required Function(bool) onSelected, Color color = Colors.blueAccent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        backgroundColor: Colors.white.withOpacity(0.05),
        selectedColor: color.withOpacity(0.2),
        checkmarkColor: color,
        labelStyle: GoogleFonts.outfit(
          color: selected ? color : Colors.white60,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? color.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
        ),
        showCheckmark: false,
      ),
    );
  }

  void _showAllFiltersBottomSheet(BuildContext context, CommunityController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Groups',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (controller.levels.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('LEVELS', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: controller.levels.map((level) => ChoiceChip(
                            label: Text(level['title'] ?? 'Level ${level['order']}'),
                            selected: controller.selectedLevelId == level['id'],
                            onSelected: (val) {
                              _controller.fetchPosts(levelId: level['id']);
                              Navigator.pop(context);
                            },
                          )).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (controller.challenges.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('CHALLENGES', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: controller.challenges.map((challenge) => ChoiceChip(
                            label: Text(challenge['title']),
                            selected: controller.selectedChallengeId == challenge['id'],
                            onSelected: (val) {
                              _controller.fetchPosts(challengeId: challenge['id']);
                              Navigator.pop(context);
                            },
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
