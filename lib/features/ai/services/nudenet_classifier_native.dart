import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/detection.dart';
import '../../../core/services/telemetry_service.dart';

class NudeNetClassifier {
  static final NudeNetClassifier instance = NudeNetClassifier._internal();
  NudeNetClassifier._internal();

  Interpreter? _interpreter;
  String _currentModelPath = '';

  bool get isInitialized => _interpreter != null;
  String get currentModelPath => _currentModelPath;

  static const List<String> labels = [
    "FEMALE_GENITALIA_COVERED",
    "FACE_FEMALE",
    "BUTTOCKS_EXPOSED",
    "FEMALE_BREAST_EXPOSED",
    "FEMALE_GENITALIA_EXPOSED",
    "MALE_BREAST_EXPOSED",
    "ANUS_EXPOSED",
    "FEET_EXPOSED",
    "BELLY_COVERED",
    "FEET_COVERED",
    "ARMPITS_COVERED",
    "ARMPITS_EXPOSED",
    "FACE_MALE",
    "BELLY_EXPOSED",
    "MALE_GENITALIA_EXPOSED",
    "ANUS_COVERED",
    "FEMALE_BREAST_COVERED",
    "BUTTOCKS_COVERED"
  ];

  /// Initialize the classifier with the asset model or a custom downloaded file path
  Future<void> init({String? customFilePath}) async {
    try {
      if (customFilePath != null && customFilePath.isNotEmpty) {
        final file = File(customFilePath);
        if (await file.exists()) {
          _interpreter = Interpreter.fromFile(file);
          _currentModelPath = customFilePath;
          print('NudeNetClassifier: Successfully loaded custom model from $customFilePath');
          return;
        }
      }

      // Fallback to default asset
      final assetBytes = await rootBundle.load('assets/models/nudenet_320n.tflite');
      final bytes = assetBytes.buffer.asUint8List();

      _interpreter = Interpreter.fromBuffer(bytes);
      _currentModelPath = 'assets/models/nudenet_320n.tflite';
      print('NudeNetClassifier: Successfully loaded default asset model');
    } catch (e) {
      print('NudeNetClassifier: Initialization failed completely: $e');
    }
  }

  /// Classify an image from raw bytes
  List<Detection> classifyImage(Uint8List imageBytes) {
    if (!isInitialized) {
      print('NudeNetClassifier error: classifier not initialized');
      return [];
    }

    try {
      // Decode image
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return [];

      // Pre-process: Resize to 320x320
      final resizedImage = img.copyResize(decodedImage, width: 320, height: 320);

      // Pre-process: Normalize pixels to [0.0, 1.0] and pack into input tensor
      // NudeNet input shape is [1, 320, 320, 3]
      var input = List.generate(
        1,
        (_) => List.generate(
          320,
          (y) => List.generate(
            320,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // Output shape: [1, 22, 2100]
      final outputShapes = _interpreter!.getOutputTensors();
      if (outputShapes.isEmpty) return [];
      
      final shape = outputShapes.first.shape;
      
      var output = List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List.filled(shape[2], 0.0),
        ),
      );

      // Run interpreter
      _interpreter!.run(input, output);

      // Increment local telemetry scans
      TelemetryService.instance.incrementScanCount();

      // Post-process the output tensors
      return _parseOutputTensors(output, decodedImage.width, decodedImage.height);
    } catch (e) {
      print('NudeNetClassifier: Inference run failed: $e');
      return [];
    }
  }

  /// Parse outputs and run NMS to get clean bounding boxes
  List<Detection> _parseOutputTensors(List<dynamic> output, int originalWidth, int originalHeight) {
    final List<Detection> candidates = [];
    final int numClasses = 18;
    final int numAnchors = 2100;
    const double confidenceThreshold = 0.25;
    const double iouThreshold = 0.45;

    final double scaleX = originalWidth / 320.0;
    final double scaleY = originalHeight / 320.0;

    final matrix = output[0] as List<List<dynamic>>;

    for (int c = 0; c < numAnchors; c++) {
      // Box coordinates: x_center, y_center, width, height (rows 0, 1, 2, 3)
      final double xCenter = (matrix[0][c] as num).toDouble();
      final double yCenter = (matrix[1][c] as num).toDouble();
      final double w = (matrix[2][c] as num).toDouble();
      final double h = (matrix[3][c] as num).toDouble();

      // Find class with highest confidence (rows 4 to 21)
      int maxClassId = -1;
      double maxScore = 0.0;

      for (int classId = 0; classId < numClasses; classId++) {
        final double score = (matrix[4 + classId][c] as num).toDouble();
        if (score > maxScore) {
          maxScore = score;
          maxClassId = classId;
        }
      }

      if (maxScore >= confidenceThreshold && maxClassId != -1) {
        final double x1 = (xCenter - w / 2.0) * scaleX;
        final double y1 = (yCenter - h / 2.0) * scaleY;
        final double boxW = w * scaleX;
        final double boxH = h * scaleY;

        candidates.add(
          Detection(
            label: labels[maxClassId],
            confidence: maxScore,
            boundingBox: Rect.fromLTWH(
              x1 < 0 ? 0 : x1,
              y1 < 0 ? 0 : y1,
              boxW,
              boxH,
            ),
          ),
        );
      }
    }

    // Apply Non-Maximum Suppression (NMS)
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<Detection> selected = [];
    for (final candidate in candidates) {
      bool keep = true;
      for (final active in selected) {
        if (active.label == candidate.label) {
          final double iou = _calculateIoU(candidate.boundingBox, active.boundingBox);
          if (iou > iouThreshold) {
            keep = false;
            break;
          }
        }
      }
      if (keep) {
        selected.add(candidate);
      }
    }

    return selected;
  }

  double _calculateIoU(Rect a, Rect b) {
    final double x1 = a.left > b.left ? a.left : b.left;
    final double y1 = a.top > b.top ? a.top : b.top;
    final double x2 = a.right < b.right ? a.right : b.right;
    final double y2 = a.bottom < b.bottom ? a.bottom : b.bottom;

    final double intersectionWidth = x2 - x1;
    final double intersectionHeight = y2 - y1;

    if (intersectionWidth <= 0 || intersectionHeight <= 0) {
      return 0.0;
    }

    final double intersectionArea = intersectionWidth * intersectionHeight;
    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;
    final double unionArea = areaA + areaB - intersectionArea;

    if (unionArea <= 0.0) return 0.0;
    return intersectionArea / unionArea;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
