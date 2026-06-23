class BlockEvent {
  final String blockType;
  final String appName;
  final String domain;
  final String url;
  final String aiClassLabel;
  final double? confidenceScore;
  final DateTime timestamp;

  BlockEvent({
    required this.blockType,
    required this.appName,
    required this.domain,
    required this.url,
    required this.aiClassLabel,
    this.confidenceScore,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'block_type': blockType,
      'app_name': appName,
      'domain': domain,
      'url': url,
      'ai_class_label': aiClassLabel,
      'confidence_score': confidenceScore,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory BlockEvent.fromJson(Map<String, dynamic> json) {
    return BlockEvent(
      blockType: json['block_type'] ?? 'dns',
      appName: json['app_name'] ?? '',
      domain: json['domain'] ?? '',
      url: json['url'] ?? '',
      aiClassLabel: json['ai_class_label'] ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  factory BlockEvent.fromLocalMap(Map<String, dynamic> map) {
    return BlockEvent(
      blockType: map['block_type'] ?? 'dns',
      appName: map['app_name'] ?? '',
      domain: map['domain'] ?? '',
      url: map['url'] ?? '',
      aiClassLabel: map['ai_class_label'] ?? '',
      confidenceScore: map['confidence_score'] != null ? (map['confidence_score'] as num).toDouble() : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'block_type': blockType,
      'app_name': appName,
      'domain': domain,
      'url': url,
      'ai_class_label': aiClassLabel,
      'confidence_score': confidenceScore,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
