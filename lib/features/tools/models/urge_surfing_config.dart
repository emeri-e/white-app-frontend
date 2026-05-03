class UrgeSurfingConfig {
  final int id;
  final String label;
  final int durationSeconds;
  final String encouragementMessage;
  final String? backgroundAnimationFile;
  final int order;

  UrgeSurfingConfig({
    required this.id,
    required this.label,
    required this.durationSeconds,
    required this.encouragementMessage,
    this.backgroundAnimationFile,
    required this.order,
  });

  factory UrgeSurfingConfig.fromJson(Map<String, dynamic> json) {
    return UrgeSurfingConfig(
      id: json['id'],
      label: json['label'] ?? '',
      durationSeconds: json['duration_seconds'] ?? 600,
      encouragementMessage: json['encouragement_message'] ?? '',
      backgroundAnimationFile: json['background_animation_file'],
      order: json['order'] ?? 0,
    );
  }
}
