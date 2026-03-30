import 'package:flutter/material.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsSheet extends StatefulWidget {
  final int mediaId;

  const CommentsSheet({super.key, required this.mediaId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    // In a real app, this would fetch from backend specifically for this media
    // For now we might need to rely on what was passed or fetch fresh
    // Assuming RecoveryService has a method or we fetch media details again
    try {
      // Simulating fetch or using existing service structure
      // Ideally: final comments = await RecoveryService.getComments(widget.mediaId);
      // For now, let's just use a placeholder if the service method doesn't exist yet
      setState(() {
        _isLoading = false;
        // _comments = comments; 
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text.trim();
    _commentController.clear();

    try {
      await RecoveryService.postComment(widget.mediaId, content);
      // Refresh comments
      await _loadComments(); 
      // Optimistic add for demo
      setState(() {
        _comments.insert(0, {
          'user': 'You', 
          'content': content, 
          'created_at': DateTime.now().toString()
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Comments',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(color: Colors.white24),
              
              // Comments List
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                    ? const Center(child: Text("No comments yet. Be the first!", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _comments.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final date = DateTime.parse(comment['created_at']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Colors.blueGrey,
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            comment['user'] ?? 'User',
                                            style: const TextStyle(
                                              color: Colors.white, 
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            timeago.format(date),
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment['content'],
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              
              // Input Field
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 8
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _postComment,
                      icon: const Icon(Icons.send, color: Colors.blueAccent),
                    ),
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
