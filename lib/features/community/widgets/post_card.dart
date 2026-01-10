import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/features/community/models/community_post.dart';
import 'package:whiteapp/features/community/screens/post_detail_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCard extends StatefulWidget {
  final CommunityPost post;

  const PostCard({Key? key, required this.post}) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showingOriginal = false;
  String? _originalText;

  Future<void> _toggleOriginalLanguage() async {
    if (_showingOriginal) {
      setState(() => _showingOriginal = false);
    } else {
      // Fetch original content
      try {
        final original = await Provider.of<CommunityController>(context, listen: false)
            .showOriginal(widget.post.id);
        setState(() {
          _originalText = original['content_text'] as String;
          _showingOriginal = true;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load original: $e')),
        );
      }
    }
  }

  Future<void> _reportTranslation() async {
    final controller = Provider.of<CommunityController>(context, listen: false);
    final success = await controller.reportTranslation(widget.post.id, 'en');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Translation issue reported'
              : 'Failed to report: ${controller.error}'),
        ),
      );
    }
  }

  Future<void> _reportPost() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReportDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      final controller = Provider.of<CommunityController>(context, listen: false);
      final success = await controller.reportContent(postId: widget.post.id, reason: reason);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Post reported'
                : 'Failed to report: ${controller.error}'),
          ),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = Provider.of<CommunityController>(context, listen: false);
      final success = await controller.deletePost(widget.post.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Post deleted'
                : 'Failed to delete: ${controller.error}'),
          ),
        );
      }
    }
  }

  Future<void> _likePost() async {
    final controller = Provider.of<CommunityController>(context, listen: false);
    await controller.reactToPost(widget.post.id, 'like');
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _showingOriginal && _originalText != null
        ? _originalText!
        : widget.post.displayText;
    
    final isTranslated = widget.post.originalLanguage != 'en' && !_showingOriginal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Row(
              children: [
                Text(
                  widget.post.authorName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.post.authorCountryFlag.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.post.authorCountryFlag,
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
                if (widget.post.isRecoveryStory) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('Recovery Story', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.green.shade100,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ],
              ],
            ),
            subtitle: Text(timeago.format(widget.post.createdAt)),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [Icon(Icons.flag), SizedBox(width: 8), Text('Report')],
                  ),
                ),
                // TODO: Add edit/delete for author
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'report') _reportPost();
                if (value == 'delete') _deletePost();
              },
            ),
          ),

          // Targeting Notice
          if (widget.post.isTargetedForViewer)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This post is targeted to a specific group inside the app.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              displayText,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          // Translation controls
          if (isTranslated)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _toggleOriginalLanguage,
                    icon: const Icon(Icons.translate, size: 16),
                    label: const Text('Show Original'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _reportTranslation,
                    icon: const Icon(Icons.report_problem, size: 16),
                    label: const Text('Report Translation'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                  ),
                ],
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _likePost,
                  icon: const Icon(Icons.favorite_border),
                  label: Text('${widget.post.reactionsCount}'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(post: widget.post),
                      ),
                    );
                  },
                  icon: const Icon(Icons.comment),
                  label: Text('${widget.post.commentsCount}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Post'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Reason',
          hintText: 'Why are you reporting this post?',
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Report'),
        ),
      ],
    );
  }
}
