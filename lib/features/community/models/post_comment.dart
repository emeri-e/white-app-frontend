// Post Comment Model with nested children support
class PostComment {
  final int id;
  final int postId;
  final int author;
  final String authorName;
  final int? parentId;
  final String contentText;
  final DateTime createdAt;
  final bool isRemoved;
  final List<PostComment> children;

  PostComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.authorName,
    this.parentId,
    required this.contentText,
    required this.createdAt,
    required this.isRemoved,
    this.children = const [],
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    var childrenList = json['children'] as List<dynamic>? ?? [];
    List<PostComment> parsedChildren = childrenList
        .map((child) => PostComment.fromJson(child as Map<String, dynamic>))
        .toList();

    return PostComment(
      id: json['id'] as int,
      postId: json['post'] as int,
      author: json['author'] as int,
      authorName: json['author_name'] as String? ?? 'User',
      parentId: json['parent'] as int?,
      contentText: json['content_text'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      isRemoved: json['is_removed'] as bool? ?? false,
      children: parsedChildren,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post': postId,
      'parent': parentId,
      'content_text': contentText,
    };
  }
}
