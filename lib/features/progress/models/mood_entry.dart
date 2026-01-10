class MoodEntry {
  final int? id;
  final String date;
  final String primaryEmotion;
  final String? secondaryEmotion;
  final int intensity;
  final String? note;

  MoodEntry({
    this.id,
    required this.date,
    required this.primaryEmotion,
    this.secondaryEmotion,
    required this.intensity,
    this.note,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'],
      date: json['date'],
      primaryEmotion: json['primary_emotion'],
      secondaryEmotion: json['secondary_emotion'],
      intensity: json['intensity'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'primary_emotion': primaryEmotion,
      'secondary_emotion': secondaryEmotion,
      'intensity': intensity,
      'note': note,
    };
  }
}
