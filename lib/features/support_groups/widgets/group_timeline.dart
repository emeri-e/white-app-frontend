import 'package:flutter/material.dart';
import 'package:whiteapp/features/support_groups/services/support_group_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class GroupTimeline extends StatefulWidget {
  final int groupId;

  const GroupTimeline({Key? key, required this.groupId}) : super(key: key);

  @override
  State<GroupTimeline> createState() => _GroupTimelineState();
}

class _GroupTimelineState extends State<GroupTimeline> {
  final TextEditingController _postController = TextEditingController();
  List<dynamic> _posts = [];
  bool _isLoading = true;
  bool _isPosting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await SupportGroupService.getTimelinePosts(widget.groupId);
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);
    try {
      await SupportGroupService.createTimelinePost(
        widget.groupId,
        _postController.text.trim(),
      );
      _postController.clear();
      await _loadPosts(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _reactToPost(int postId, String type) async {
    try {
      await SupportGroupService.reactToTimelinePost(widget.groupId, postId, type);
      await _loadPosts(); // Refresh to update counts
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to react: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Timeline Feed
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _posts.isEmpty
                      ? const Center(child: Text('No posts yet. Start the discussion!'))
                      : ListView.builder(
                          reverse: true, // Show newest at bottom like chat? Or top?
                          // Usually timeline is newest at top. But chat is newest at bottom.
                          // User said "Group Timeline (like a live feed)".
                          // Let's stick to standard feed: newest at top.
                          padding: const EdgeInsets.all(16),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            return _buildPostCard(post);
                          },
                        ),
        ),

        // Post Input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _postController,
                  decoration: const InputDecoration(
                    hintText: 'Share your thoughts...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isPosting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: _isPosting ? null : _createPost,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(dynamic post) {
    final bool isLiked = post['is_liked_by_me'] ?? false;
    final int reactionsCount = post['reactions_count'] ?? 0;
    final DateTime createdAt = DateTime.parse(post['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  post['author_name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  timeago.format(createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post['content_text']),
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  onTap: () => _reactToPost(post['id'], 'like'),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isLiked ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$reactionsCount',
                        style: TextStyle(
                          color: isLiked ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add more actions like Reply if needed
              ],
            ),
          ],
        ),
      ),
    );
  }
}
