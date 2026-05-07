import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/gemini_service.dart';
import '../widgets/part_overlay_painter.dart';

class RepairARScreen extends StatefulWidget {
  const RepairARScreen({super.key});

  @override
  State<RepairARScreen> createState() => _RepairARScreenState();
}

class _RepairARScreenState extends State<RepairARScreen> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  final GeminiService _geminiService = GeminiService();

  List<DetectedObject> _detections = [];
  String? _selectedPartGuide;
  String? _selectedPartName;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController.initialize();
    if (mounted) setState(() => _isCameraInitialized = true);
  }

  Future<void> _captureAndDetect() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _detections = [];
      _selectedPartGuide = null;
      _selectedPartName = null;
    });

    try {
      final picture = await _cameraController.takePicture();
      final detections = await _geminiService.detectParts(File(picture.path));

      if (mounted) {
        setState(() => _detections = detections);
        if (detections.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No parts detected. Try again with better lighting.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Detection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _onPartTapped(DetectedObject part) async {
    setState(() {
      _selectedPartName = part.label;
      _selectedPartGuide = 'Loading repair guide for ${part.label}...';
    });

    final guide = await _geminiService.getRepairGuide(
      part.label,
      'What are common issues with this part and how do I fix them?',
    );

    if (mounted) setState(() => _selectedPartGuide = guide);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('AR Part Detector'),
        actions: [
          if (_detections.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                _detections = [];
                _selectedPartGuide = null;
                _selectedPartName = null;
              }),
            )
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_cameraController),

          // Overlay boxes
          if (_detections.isNotEmpty)
            Positioned.fill(
              child: GestureDetector(
                onTapUp: (details) {
                  final size = MediaQuery.of(context).size;
                  final dx = details.localPosition.dx / size.width;
                  final dy = details.localPosition.dy / size.height;
                  for (final det in _detections) {
                    if (dx >= det.left &&
                        dx <= det.right &&
                        dy >= det.top &&
                        dy <= det.bottom) {
                      _onPartTapped(det);
                      break;
                    }
                  }
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: PartOverlayPainter(_detections),
                ),
              ),
            ),

          // Repair guide card
          if (_selectedPartGuide != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 100,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedPartName ?? '',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          _selectedPartGuide!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Hint text
          if (_detections.isEmpty && !_isProcessing)
            const Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Tap the scan button to detect parts',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),

          // Scan button
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: _isProcessing ? null : _captureAndDetect,
              backgroundColor: Colors.greenAccent,
              label: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
                  : const Text('Scan',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              icon: _isProcessing
                  ? const SizedBox.shrink()
                  : const Icon(Icons.search, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}