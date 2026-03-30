class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleLine({
    required this.start,
    required this.end,
    required this.text,
  });

  @override
  String toString() => 'SubtitleLine(start: $start, end: $end, text: $text)';
}

class SrtParser {
  static List<SubtitleLine> parse(String content) {
    final List<SubtitleLine> lines = [];
    final List<String> blocks = content.trim().split(RegExp(r'\n\s*\n'));

    for (var block in blocks) {
      final List<String> parts = block.split('\n');
      if (parts.length < 3) continue;

      // Part 0 logic: Index (ignored)
      // Part 1: 00:00:20,000 --> 00:00:24,400
      final timePart = parts[1];
      final timeMatch = RegExp(r'(\d+:\d+:\d+,\d+)\s*-->\s*(\d+:\d+:\d+,\d+)').firstMatch(timePart);
      
      if (timeMatch != null) {
        final start = _parseTime(timeMatch.group(1)!);
        final end = _parseTime(timeMatch.group(2)!);
        final text = parts.sublist(2).join('\n').trim();
        
        lines.add(SubtitleLine(start: start, end: end, text: text));
      }
    }
    return lines;
  }

  static Duration _parseTime(String timeStr) {
    // 00:00:20,000
    final parts = timeStr.split(RegExp(r'[:|,]'));
    if (parts.length != 4) return Duration.zero;

    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(parts[2]),
      milliseconds: int.parse(parts[3]),
    );
  }
}
