import 'package:flutter_test/flutter_test.dart';
import 'package:whiteapp/core/parsers/srt_parser.dart';

void main() {
  test('SrtParser parses a standard SRT string', () {
    const srtContent = '''
1
00:00:01,000 --> 00:00:04,000
Hello World

2
00:00:05,500 --> 00:00:08,200
This is a test subtitle
with multiple lines
''';

    final lines = SrtParser.parse(srtContent);

    expect(lines.length, 2);
    
    expect(lines[0].start, const Duration(seconds: 1));
    expect(lines[0].end, const Duration(seconds: 4));
    expect(lines[0].text, 'Hello World');

    expect(lines[1].start, const Duration(seconds: 5, milliseconds: 500));
    expect(lines[1].end, const Duration(seconds: 8, milliseconds: 200));
    expect(lines[1].text, 'This is a test subtitle\nwith multiple lines');
  });

  test('SrtParser handles empty or malformed input', () {
    expect(SrtParser.parse('').length, 0);
    expect(SrtParser.parse('garbage').length, 0);
  });
}
