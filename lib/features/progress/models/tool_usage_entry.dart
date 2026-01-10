class ToolUsageEntry {
  final int? id;
  final String toolType;
  final String usedAt;
  final int durationSeconds;

  ToolUsageEntry({
    this.id,
    required this.toolType,
    required this.usedAt,
    required this.durationSeconds,
  });

  factory ToolUsageEntry.fromJson(Map<String, dynamic> json) {
    return ToolUsageEntry(
      id: json['id'],
      toolType: json['tool_type'],
      usedAt: json['used_at'],
      durationSeconds: json['duration_seconds'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tool_type': toolType,
      'used_at': usedAt,
      'duration_seconds': durationSeconds,
    };
  }
}
