import '../models/detection.dart';

class BlockDecision {
  final bool blocked;
  final String triggeringClass;
  final double confidence;
  final List<Detection> detections;

  const BlockDecision({
    required this.blocked,
    required this.triggeringClass,
    required this.confidence,
    required this.detections,
  });

  factory BlockDecision.clean(List<Detection> detections) {
    return BlockDecision(
      blocked: false,
      triggeringClass: '',
      confidence: 0.0,
      detections: detections,
    );
  }

  factory BlockDecision.blocked({
    required String triggeringClass,
    required double confidence,
    required List<Detection> detections,
  }) {
    return BlockDecision(
      blocked: true,
      triggeringClass: triggeringClass,
      confidence: confidence,
      detections: detections,
    );
  }
}

class BlockingDecision {
  static final BlockingDecision instance = BlockingDecision._internal();
  BlockingDecision._internal();

  // Dynamic sensitivity thresholds that can be loaded from SQLite
  Map<String, double> _thresholds = {
    'GENITALIA_EXPOSED': 0.65,
    'FEMALE_GENITALIA_EXPOSED': 0.65,
    'MALE_GENITALIA_EXPOSED': 0.65,
    'ANUS_EXPOSED': 0.65,
    'FEMALE_BREAST_EXPOSED': 0.75,
    'BUTTOCKS_EXPOSED': 0.70,
    'GENITALIA_COVERED': 0.80,
    'FEMALE_BREAST_COVERED': 0.85,
    'BUTTOCKS_COVERED': 0.85,
    'MALE_BREAST_EXPOSED': 0.80,
    'BELLY_EXPOSED': 0.80,
    'FEET_EXPOSED': 0.90,
    'ARMPITS_EXPOSED': 0.90,
  };

  // Flag indicating if a class is allowed to trigger a block by itself
  final Set<String> _compositeOnlyClasses = {
    'GENITALIA_COVERED',
    'FEMALE_BREAST_COVERED',
    'BUTTOCKS_COVERED',
    'MALE_BREAST_EXPOSED',
    'BELLY_EXPOSED',
    'FEET_EXPOSED',
    'ARMPITS_EXPOSED',
  };

  /// Update thresholds from local SQLite config
  void updateThresholds(Map<String, double> newThresholds) {
    _thresholds.addAll(newThresholds);
    print('BlockingDecision: Loaded ${_thresholds.length} active class thresholds');
  }

  /// Evaluates detections to decide if content should be blocked
  BlockDecision evaluateDetections(List<Detection> detections) {
    if (detections.isEmpty) {
      return BlockDecision.clean(detections);
    }

    double compositeScore = 0.0;
    Detection? strongestCompositeDetection;

    for (final detection in detections) {
      final label = detection.label.toUpperCase();
      final conf = detection.confidence;

      // Get threshold for this label (fallback to 0.75 if unspecified)
      final threshold = _thresholds[label] ?? 0.75;

      // Rule 1: Direct trigger classes (Non-composite-only)
      final isCompositeOnly = _compositeOnlyClasses.contains(label);
      if (!isCompositeOnly && conf >= threshold) {
        return BlockDecision.blocked(
          triggeringClass: label,
          confidence: conf,
          detections: detections,
        );
      }

      // Rule 2: Composite scoring
      if (conf >= threshold) {
        compositeScore += (conf - threshold + 0.1);
        if (strongestCompositeDetection == null || conf > strongestCompositeDetection.confidence) {
          strongestCompositeDetection = detection;
        }
      }
    }

    // If multiple composite classes are exposed, they can trigger a block together
    if (compositeScore >= 0.6 && strongestCompositeDetection != null) {
      return BlockDecision.blocked(
        triggeringClass: 'COMPOSITE_${strongestCompositeDetection.label.toUpperCase()}',
        confidence: strongestCompositeDetection.confidence,
        detections: detections,
      );
    }

    return BlockDecision.clean(detections);
  }
}
