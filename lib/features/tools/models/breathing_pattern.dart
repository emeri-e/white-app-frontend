class BreathingPattern {
  final int id;
  final String name;
  final int inhaleSeconds;
  final int holdSeconds;
  final int exhaleSeconds;
  final int postExhaleHoldSeconds;
  final int totalCycles;
  final String description;
  final bool hapticsEnabled;
  final bool animationEnabled;
  final int order;

  BreathingPattern({
    required this.id,
    required this.name,
    required this.inhaleSeconds,
    required this.holdSeconds,
    required this.exhaleSeconds,
    required this.postExhaleHoldSeconds,
    required this.totalCycles,
    required this.description,
    required this.hapticsEnabled,
    required this.animationEnabled,
    required this.order,
  });

  factory BreathingPattern.fromJson(Map<String, dynamic> json) {
    return BreathingPattern(
      id: json['id'],
      name: json['name'] ?? '',
      inhaleSeconds: json['inhale_seconds'] ?? 4,
      holdSeconds: json['hold_seconds'] ?? 4,
      exhaleSeconds: json['exhale_seconds'] ?? 4,
      postExhaleHoldSeconds: json['post_exhale_hold_seconds'] ?? 4,
      totalCycles: json['total_cycles'] ?? 4,
      description: json['description'] ?? '',
      hapticsEnabled: json['haptics_enabled'] ?? true,
      animationEnabled: json['animation_enabled'] ?? true,
      order: json['order'] ?? 0,
    );
  }
}
