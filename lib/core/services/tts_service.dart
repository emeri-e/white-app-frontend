import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Future<void> init() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45); // Slightly slower for better clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.95);  // Slightly lower pitch for a more natural tone

    _flutterTts.setStartHandler(() {
      _isPlaying = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isPlaying = false;
    });
  }

  Future<void> speak(String text, {String lang = "en-US"}) async {
    if (text.isEmpty) return;
    await _flutterTts.setLanguage(lang);
    await _flutterTts.speak(text);
    _isPlaying = true;
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _isPlaying = false;
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
  }

  FlutterTts get tts => _flutterTts;
}
