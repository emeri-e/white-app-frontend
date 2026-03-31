import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
            content: Text(success ? 'Post reported' : 'Failed to report: ${controller.error}'),
          ),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Delete Post', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('Are you sure you want to delete this post?', style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white30)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = Provider.of<CommunityController>(context, listen: false);
      final success = await controller.deletePost(widget.post.id);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${controller.error}')),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.post.authorName,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.post.authorCountryFlag.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(widget.post.authorCountryFlag, style: const TextStyle(fontSize: 14)),
                            ],
                          ],
                        ),
                        Text(
                          timeago.format(widget.post.createdAt),
                          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildMenuButton(),
                ],
              ),
            ),

            // Target/Context Badges
            _buildContextBadges(),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                displayText,
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),

            // Translations
            if (isTranslated) _buildTranslationControls(),

            // Media (Placeholder for now, can be expanded)
            if (widget.post.media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Icon(Icons.image, color: Colors.white24, size: 48)),
                ),
              ),

            const SizedBox(height: 12),

            // Action Bar
            _buildActionBar(),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withOpacity(0.2), Colors.purpleAccent.withOpacity(0.2)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          widget.post.authorName.isNotEmpty ? widget.post.authorName[0].toUpperCase() : '?',
          style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMenuButton() {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white30),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Text('Report', style: GoogleFonts.outfit(color: Colors.white70)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Text('Delete', style: GoogleFonts.outfit(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'report') _reportPost();
        if (value == 'delete') _deletePost();
      },
    );
  }

  Widget _buildContextBadges() {
    final List<Widget> badges = [];

    if (widget.post.isRecoveryStory) {
      badges.add(_buildBadge("Recovery Story", Colors.greenAccent));
    }

    if (widget.post.level != null) {
      badges.add(_buildBadge("Level ${widget.post.level!['order']}", Colors.blueAccent));
    }

    if (widget.post.challenge != null) {
      badges.add(_buildBadge(widget.post.challenge!['title'], Colors.orangeAccent));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(spacing: 8, runSpacing: 8, children: badges),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTranslationControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTextButton(
            onPressed: _toggleOriginalLanguage,
            icon: Icons.translate_rounded,
            label: "Show Original",
            color: Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _buildActionButton(
            onPressed: _likePost,
            icon: Icons.favorite_rounded,
            activeIcon: Icons.favorite_rounded,
            label: "${widget.post.reactionsCount}",
            color: Colors.redAccent,
            isActive: false, // TODO: Check if user liked
          ),
          const SizedBox(width: 4),
          _buildActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post)),
              );
            },
            icon: Icons.chat_bubble_outline_rounded,
            label: "${widget.post.commentsCount}",
            color: Colors.blueAccent,
          ),
          const Spacer(),
          IconButton(
            onPressed: () {}, // TODO: Share functionality
            icon: const Icon(Icons.share_rounded, color: Colors.white30, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    IconData? activeIcon,
    required String label,
    required Color color,
    bool isActive = false,
  }) {
    final currentColor = isActive ? color : Colors.white30;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: currentColor,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(isActive ? (activeIcon ?? icon) : icon, size: 20, color: currentColor),
      label: Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextButton({required VoidCallback onPressed, required IconData icon, required String label, required Color color}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
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
      backgroundColor: const Color(0xFF1E293B),
      title: Text('Report Post', style: GoogleFonts.outfit(color: Colors.white)),
      content: TextField(
        controller: _controller,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Reason',
          labelStyle: GoogleFonts.outfit(color: Colors.white30),
          hintText: 'Why are you reporting this post?',
          hintStyle: GoogleFonts.outfit(color: Colors.white10),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white30)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text('Report', style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
