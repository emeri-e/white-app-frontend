class ToolUsageLog {
  final int id;
  final String toolType;
  final int? toolConfigId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool completed;
  final int durationSeconds;
  final Map<String, dynamic> metadata;

  ToolUsageLog({
    required this.id,
    required this.toolType,
    this.toolConfigId,
    required this.startedAt,
    this.endedAt,
    required this.completed,
    required this.durationSeconds,
    required this.metadata,
  });

  factory ToolUsageLog.fromJson(Map<String, dynamic> json) {
    return ToolUsageLog(
      id: json['id'],
      toolType: json['tool_type'] ?? '',
      toolConfigId: json['tool_config_id'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      completed: json['completed'] ?? false,
      durationSeconds: json['duration_seconds'] ?? 0,
      metadata: json['metadata'] ?? {},
    );
  }
}
