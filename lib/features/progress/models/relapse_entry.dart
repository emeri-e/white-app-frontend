class RelapseEntry {
  final int? id;
  final String date;
  final String? cause;
  final String? emotions;
  final String? notes;
  final String? audioPath;

  RelapseEntry({
    this.id,
    required this.date,
    this.cause,
    this.emotions,
    this.notes,
    this.audioPath,
  });

  factory RelapseEntry.fromJson(Map<String, dynamic> json) {
    return RelapseEntry(
      id: json['id'],
      date: json['date'],
      cause: json['cause'],
      emotions: json['emotions'],
      notes: json['notes'],
      audioPath: json['audio_log'], // Map backend field
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'cause': cause,
      'emotions': emotions,
      'notes': notes,
      // audioPath is handled separately in multipart request
    };
  }
}
