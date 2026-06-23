import 'dart:ui';

class Detection {
  final String label;
  final double confidence;
  final Rect boundingBox;

  const Detection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': confidence,
      'x': boundingBox.left,
      'y': boundingBox.top,
      'w': boundingBox.width,
      'h': boundingBox.height,
    };
  }

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: Rect.fromLTWH(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
        (json['w'] as num).toDouble(),
        (json['h'] as num).toDouble(),
      ),
    );
  }

  @override
  String toString() {
    return 'Detection(label: $label, confidence: ${confidence.toStringAsFixed(2)}, rect: $boundingBox)';
  }
}
