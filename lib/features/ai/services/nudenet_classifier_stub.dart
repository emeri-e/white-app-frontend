import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/detection.dart';

class NudeNetClassifier {
  static final NudeNetClassifier instance = NudeNetClassifier._internal();
  NudeNetClassifier._internal();

  bool get isInitialized => true;
  bool get isDummyModel => true;
  String get currentModelPath => 'web_dummy_stub';

  Future<void> init({String? customFilePath}) async {
    print('NudeNetClassifier (Web Stub): Mock initialized successfully');
  }

  List<Detection> classifyImage(Uint8List imageBytes) {
    return _generateMockDetections(imageBytes);
  }

  List<Detection> _generateMockDetections(Uint8List imageBytes) {
    final List<Detection> detections = [];
    final String contentString = String.fromCharCodes(imageBytes.take(200));
    
    if (contentString.contains('NSFW_TRIGGER_GENITALIA') || contentString.contains('nsfw_genitalia')) {
      detections.add(
        const Detection(
          label: 'GENITALIA_EXPOSED',
          confidence: 0.92,
          boundingBox: Rect.fromLTWH(50, 50, 100, 120),
        ),
      );
    } else if (contentString.contains('NSFW_TRIGGER_BREAST') || contentString.contains('nsfw_breast')) {
      detections.add(
        const Detection(
          label: 'FEMALE_BREAST_EXPOSED',
          confidence: 0.88,
          boundingBox: Rect.fromLTWH(80, 70, 80, 80),
        ),
      );
    } else if (contentString.contains('NSFW_TRIGGER_COMPOSITE') || contentString.contains('nsfw_composite')) {
      detections.add(
        const Detection(
          label: 'BELLY_EXPOSED',
          confidence: 0.82,
          boundingBox: Rect.fromLTWH(100, 120, 60, 60),
        ),
      );
      detections.add(
        const Detection(
          label: 'BUTTOCKS_EXPOSED',
          confidence: 0.58,
          boundingBox: Rect.fromLTWH(110, 140, 70, 70),
        ),
      );
    }
    
    return detections;
  }

  void close() {}
}
