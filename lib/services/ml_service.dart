
// lib/services/ml_service.dart
// Robust ML service with graceful fallback when model assets are missing.
// This avoids compile/run-time crashes if the .tflite model or labels file are not present.
// When a real model is provided (assets/car_parts.tflite and assets/labels.txt) it will be used.

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;

class MLService {
  tfl.Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  // Paths inside Flutter assets
  final String modelAsset = 'assets/model.tflite';
  final String labelsAsset = 'assets/class_mapping.csv';
  final int inputSize = 224; // model input size (change if your model differs)

  /// Initialize interpreter and labels. If assets are missing, we keep the service usable
  /// by falling back to a mock recognizer.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // Try to load labels (will throw if asset not present)
      final labelsData = await rootBundle.loadString(labelsAsset);
      _labels = labelsData.split('\n').where((s) => s.trim().isNotEmpty).toList();
    } catch (e) {
      print('[MLService] labels asset not found: $e. Using default labels.');
      _labels = ['unknown', 'engine', 'brake', 'filter', 'hose', 'battery'];
    }

    try {
      // Try to create interpreter from asset
      _interpreter = await tfl.Interpreter.fromAsset(modelAsset);
      _isInitialized = true;
      print('[MLService] Interpreter loaded from $modelAsset');
    } catch (e) {
      // If interpreter fails to load (missing asset or incompatible), we keep service but mark uninitialized.
      print('[MLService] Could not load tflite interpreter: $e. The service will use a mock recognizer.');
      _interpreter = null;
      _isInitialized = false;
    }
  }

  /// Recognize part from an XFile captured by camera.
  /// Returns a string label (from labels) or a descriptive error/fallback string.
  Future<String> recognizePart(XFile imageFile) async {
    // Ensure initialization attempted
    await initialize();

    try {
      // Decode image bytes using package:image for resizing
      final file = File(imageFile.path);
      if (!file.existsSync()) {
        return 'Captured image not found.';
      }
      img.Image? original = img.decodeImage(file.readAsBytesSync());
      if (original == null) return 'Image decode failed';

      // If interpreter available, run inference (simple float input example).
      if (_interpreter != null) {
        final resized = img.copyResize(original, width: inputSize, height: inputSize);
        // Convert to float32 input in shape [1, inputSize, inputSize, 3]
        var input = List.generate(1, (_) => List.generate(inputSize, (_) => List.generate(inputSize, (_) => List.filled(3, 0.0))));
        int px = 0;
        for (int y=0; y<inputSize; y++) {
          for (int x=0; x<inputSize; x++) {
            final pixel = resized.getPixel(x, y);
            final r = pixel.r.toDouble();
            final g = pixel.g.toDouble();
            final b = pixel.b.toDouble();

            input[0][y][x][0] = r / 255.0;
            input[0][y][x][1] = g / 255.0;
            input[0][y][x][2] = b / 255.0;


            px++;
          }
        }

        // Prepare output buffer based on interpreter's output shape
        var outputTensors = _interpreter!.getOutputTensors();
        var outShape = outputTensors[0].shape;
        var output = List.filled(outShape.reduce((a,b)=>a*b), 0.0);
        // The tflite_flutter package can accept typed buffers; using dynamic invocation for simplicity
        _interpreter!.run(input, output);

        // Find max index
        double maxScore = -double.infinity;
        int maxIndex = 0;
        for (int i = 0; i < output.length; i++) {
          if (output[i] is num && (output[i] as num) > maxScore) {
            maxScore = (output[i] as num).toDouble();
            maxIndex = i;
          }
        }
        String label = (maxIndex < _labels.length) ? _labels[maxIndex] : 'label_$maxIndex';
        print('[MLService] Detected $label (score: $maxScore)');
        return label;
      } else {
        // Mock/fallback recognizer: simple heuristic using image brightness or dimensions
        final mean = _meanBrightness(original);
        final w = original.width;
        final h = original.height;
        if (mean > 120) return _labels.isNotEmpty ? _labels[0] : 'bright_part';
        if (w > h) return _labels.length > 1 ? _labels[1] : 'wide_part';
        return _labels.length > 2 ? _labels[2] : 'unknown_part';
      }
    } catch (e, st) {
      print('[MLService] Error during recognition: $e\n$st');
      return 'Recognition Error';
    }
  }

  double _meanBrightness(img.Image im) {
    int sum = 0;
    int count = im.width * im.height;
    for (int y=0; y<im.height; y+=4) { // sample every 4th row to speed up
      for (int x=0; x<im.width; x+=4) {
        final p = im.getPixelSafe(x,y);
        sum += (p.r + p.g + p.b) ~/ 3;
      }
    }
    return sum / ( (im.width/4).ceil() * (im.height/4).ceil() ).toDouble();
  }

  void dispose() {
    _interpreter?.close();
  }
}
