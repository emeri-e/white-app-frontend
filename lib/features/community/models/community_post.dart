// Community Post Model
class CommunityPost {
  final int id;
  final int author;
  final String authorName;
  final String authorCountryFlag;
  final String visibility;
  final String originalLanguage;
  final String contentText;
  final String displayText;
  final bool isRecoveryStory;
  final int? challengeDay;
  final String moderationStatus;
  final bool allowComments;
  final String? targetGender;
  final String? targetCountry;
  final int? targetProgram;
  final Map<String, dynamic>? targetInfo;
  final String countrySnapshot;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRemoved;
  final List<dynamic> media;
  final List<dynamic> translations;
  final int commentsCount;
  final int reactionsCount;
  final int? levelId;
  final int? challengeId;
  final Map<String, dynamic>? level;
  final Map<String, dynamic>? challenge;
  final bool isTargetedForViewer;

  CommunityPost({
    required this.id,
    required this.author,
    required this.authorName,
    required this.authorCountryFlag,
    required this.visibility,
    required this.originalLanguage,
    required this.contentText,
    required this.displayText,
    required this.isRecoveryStory,
    this.challengeDay,
    required this.moderationStatus,
    required this.allowComments,
    this.targetGender,
    this.targetCountry,
    this.targetProgram,
    this.targetInfo,
    required this.countrySnapshot,
    required this.createdAt,
    required this.updatedAt,
    required this.isRemoved,
    required this.media,
    required this.translations,
    required this.commentsCount,
    required this.reactionsCount,
    this.levelId,
    this.challengeId,
    this.level,
    this.challenge,
    required this.isTargetedForViewer,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as int,
      author: json['author'] as int,
      authorName: json['author_name'] as String? ?? 'User',
      authorCountryFlag: json['author_country_flag'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'public',
      originalLanguage: json['original_language'] as String? ?? 'en',
      contentText: json['content_text'] as String? ?? '',
      displayText: json['display_text'] as String? ?? '',
      isRecoveryStory: json['is_recovery_story'] as bool? ?? false,
      challengeDay: json['challenge_day'] as int?,
      moderationStatus: json['moderation_status'] as String? ?? 'pending',
      allowComments: json['allow_comments'] as bool? ?? true,
      targetGender: json['target_gender'] as String?,
      targetCountry: json['target_country'] as String?,
      targetProgram: json['target_program'] as int?,
      targetInfo: json['target_info'] as Map<String, dynamic>?,
      countrySnapshot: json['country_snapshot'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isRemoved: json['is_removed'] as bool? ?? false,
      media: json['media'] as List<dynamic>? ?? [],
      translations: json['translations'] as List<dynamic>? ?? [],
      commentsCount: json['comments_count'] as int? ?? 0,
      reactionsCount: json['reactions_count'] as int? ?? 0,
      levelId: json['level_id'] as int?,
      challengeId: json['challenge_id'] as int?,
      level: json['level'] as Map<String, dynamic>?,
      challenge: json['challenge'] as Map<String, dynamic>?,
      isTargetedForViewer: json['is_targeted_for_viewer'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'author_name': authorName,
      'visibility': visibility,
      'original_language': originalLanguage,
      'content_text': contentText,
      'is_recovery_story': isRecoveryStory,
      'challenge_day': challengeDay,
      'moderation_status': moderationStatus,
      'allow_comments': allowComments,
      'target_gender': targetGender,
      'target_country': targetCountry,
      'target_program': targetProgram,
      'level_id': levelId,
      'challenge_id': challengeId,
      'country_snapshot': countrySnapshot,
    };
  }
}
