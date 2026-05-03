class SoundscapeTrack {
  final int id;
  final String name;
  final String iconName;
  final String audioFile;
  final int order;

  SoundscapeTrack({
    required this.id,
    required this.name,
    required this.iconName,
    required this.audioFile,
    required this.order,
  });

  factory SoundscapeTrack.fromJson(Map<String, dynamic> json) {
    return SoundscapeTrack(
      id: json['id'],
      name: json['name'] ?? '',
      iconName: json['icon_name'] ?? '',
      audioFile: json['audio_file'] ?? '',
      order: json['order'] ?? 0,
    );
  }
}
