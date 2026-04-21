import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/features/community/models/community_post.dart';
import 'package:whiteapp/features/community/screens/post_detail_screen.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
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

  Future<void> _reportPost() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _ReasonDialog(
        title: 'Report Post',
        hintText: 'Why are you reporting this post?',
        submitLabel: 'Report',
      ),
    );

    if (reason != null && mounted) {
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
        border: Border.all(
          color: widget.post.moderationStatus == 'pending' 
              ? Colors.orangeAccent.withOpacity(0.3) 
              : (widget.post.moderationStatus == 'rejected' ? Colors.redAccent.withOpacity(0.3) : Colors.white10),
        ),
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
                  GestureDetector(
                    onTap: widget.post.visibility == 'anonymous' 
                      ? null 
                      : () => Navigator.pushNamed(
                          context, 
                          '/public-profile', 
                          arguments: widget.post.author
                        ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white10,
                          backgroundImage: widget.post.authorAvatar != null 
                            ? NetworkImage(widget.post.authorAvatar!) 
                            : null,
                          child: widget.post.authorAvatar == null 
                            ? const Icon(Icons.person, size: 18, color: Colors.white30) 
                            : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.post.authorName,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                    decoration: widget.post.visibility == 'anonymous' 
                                      ? TextDecoration.none 
                                      : TextDecoration.underline,
                                    decorationColor: Colors.white24,
                                  ),
                                ),
                                if (widget.post.authorCountryFlag.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(widget.post.authorCountryFlag, style: const TextStyle(fontSize: 12)),
                                ],
                              ],
                            ),
                            Text(
                              '${widget.post.createdAt.day} ${_getMonth(widget.post.createdAt.month)} • ${_getTimeAgo(widget.post.createdAt)}',
                              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildMenuButton(),
                ],
              ),
            ),

            // Moderation Actions for Staff
            _buildModerationActions(),

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
    final user = ProfileService.cachedProfile?.user;
    final isAuthor = user?.id == widget.post.author;
    final isStaff = user?.isStaff ?? false;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white38),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'report') _reportPost();
        if (value == 'delete') _deletePost();
      },
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
        if (isAuthor || isStaff)
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

    // Moderation Status Badges
    if (widget.post.moderationStatus == 'pending') {
      badges.add(_buildBadge("Pending Review", Colors.orangeAccent));
    } else if (widget.post.moderationStatus == 'rejected') {
      badges.add(_buildBadge("Rejected", Colors.redAccent));
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

  Widget _buildModerationActions() {
    final currentUser = ProfileService.cachedProfile?.user;
    if (currentUser == null || !currentUser.isStaff) return const SizedBox.shrink();
    if (widget.post.moderationStatus != 'pending') return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MODERATION QUEUE',
            style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModerationButton(
                  label: 'APPROVE',
                  icon: Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  onPressed: () => Provider.of<CommunityController>(context, listen: false).approvePost(widget.post.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModerationButton(
                  label: 'REJECT',
                  icon: Icons.cancel_rounded,
                  color: Colors.redAccent,
                  onPressed: () async {
                    final reason = await showDialog<String>(
                      context: context,
                      builder: (context) => const _ReasonDialog(
                        title: 'Reject Post',
                        hintText: 'Provide a reason (optional)...',
                        submitLabel: 'Reject',
                        isOptional: true,
                      ),
                    );
                    if (reason != null && mounted) {
                      Provider.of<CommunityController>(context, listen: false).rejectPost(widget.post.id, reason: reason);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModerationButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
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

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getTimeAgo(DateTime date) {
    return timeago.format(date);
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String submitLabel;
  final bool isOptional;

  const _ReasonDialog({
    required this.title,
    required this.hintText,
    required this.submitLabel,
    this.isOptional = false,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      content: TextField(
        controller: _controller,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Reason${widget.isOptional ? " (Optional)" : ""}',
          labelStyle: GoogleFonts.outfit(color: Colors.white30),
          hintText: widget.hintText,
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
          child: Text(widget.submitLabel, style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
