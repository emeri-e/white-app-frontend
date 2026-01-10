import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/features/community/widgets/post_card.dart';
import 'package:whiteapp/features/community/screens/create_post_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({Key? key}) : super(key: key);

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen>
    with SingleTickerProviderStateMixin {
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
    await _controller.fetchProgramDetails(); // Fetch levels/challenges first
    await _controller.fetchPosts();
    await _controller.fetchRecoveryStories();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCountryFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Country Filter'),
        content: const Text(
          'Country filtering is managed in Settings.\nGo to Profile > Settings to change your country preference.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showCountryFilter,
            tooltip: 'Country Filter',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Posts'),
            Tab(text: 'Recovery Stories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllPostsTab(),
          _buildRecoveryStoriesTab(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreatePostScreen(),
              ),
            ).then((_) => _loadData());
          },
          icon: const Icon(Icons.add),
          label: const Text('New Post'),
        ),
      ),
    );
  }

  Widget _buildAllPostsTab() {
    return Column(
      children: [
        _buildFilterSelector(),
        Expanded(
          child: Consumer<CommunityController>(
            builder: (context, controller, child) {
              if (controller.isLoading && controller.posts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${controller.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (controller.posts.isEmpty) {
                return const Center(
                  child: Text('No posts yet. Be the first to share!'),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  itemCount: controller.posts.length,
                  itemBuilder: (context, index) {
                    return PostCard(post: controller.posts[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecoveryStoriesTab() {
    return Consumer<CommunityController>(
      builder: (context, controller, child) {
        if (controller.isLoading && controller.recoveryStories.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.recoveryStories.isEmpty) {
          return const Center(
            child: Text('No recovery stories yet.'),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            itemCount: controller.recoveryStories.length,
            itemBuilder: (context, index) {
              return PostCard(post: controller.recoveryStories[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterSelector() {
    return Consumer<CommunityController>(
      builder: (context, controller, child) {
        if (controller.levels.isEmpty && controller.challenges.isEmpty) {
          return const SizedBox.shrink(); // Hide if no program details
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: controller.selectedLevelId == null && controller.selectedChallengeId == null,
                      onSelected: (selected) {
                        if (selected) {
                          _controller.fetchPosts(levelId: null, challengeId: null);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Levels
                    ...controller.levels.map((level) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(level['title'] ?? 'Level ${level['order']}'),
                          selected: controller.selectedLevelId == level['id'],
                          onSelected: (selected) {
                            _controller.fetchPosts(
                              levelId: selected ? level['id'] : null,
                              challengeId: null, // Clear challenge if level selected
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Challenges
                    ...controller.challenges.map((challenge) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(challenge['title'] ?? 'Challenge'),
                          selected: controller.selectedChallengeId == challenge['id'],
                          onSelected: (selected) {
                            _controller.fetchPosts(
                              challengeId: selected ? challenge['id'] : null,
                              levelId: null, // Clear level if challenge selected
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
