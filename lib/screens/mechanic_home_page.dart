// lib/screens/mechanic_home_page.dart
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/gemini_service.dart';
// import '../services/ml_service.dart';
import '../widgets/camera_view.dart';
import '../widgets/response_card.dart';
import 'repair_ar_screen.dart';

class MechanicHomePage extends StatefulWidget {
  const MechanicHomePage({super.key});

  @override
  State<MechanicHomePage> createState() => _MechanicHomePageState();
}

class _MechanicHomePageState extends State<MechanicHomePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  String _recognizedPart = '';
  String _repairGuide =
      'Capture a part and ask a question to get your AI repair guide.';
  bool _isLoading = false;
  final TextEditingController _questionController = TextEditingController();
  // final MLService _mlService = MLService();
  final GeminiService _geminiService = GeminiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _repairGuide = "No cameras found on device.";
        });
        return;
      }
      final rearCamera = cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);

      _controller = CameraController(
        rearCamera,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeControllerFuture = _controller!.initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((e) {
        if (e is CameraException) {
          _repairGuide = "Camera Error: ${e.description}";
        } else {
          _repairGuide = "Unknown camera error: $e";
        }
        if (mounted) setState(() {});
      });

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _repairGuide = "Failed to initialize camera: $e";
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isLoading) {
      return;
    }

    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please type your question about the part first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _repairGuide = 'Processing image and generating guide...';
      _recognizedPart = '';
    });

    try {
      // 1. Capture Image
      final image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });

      // 2. ML Recognition
      final detections = await _geminiService.detectParts(File(image.path));
      final partName = detections.isNotEmpty ? detections.first.label : 'unknown part';
      setState(() {
        _recognizedPart = partName;
      });

      // 3. AI Guide Generation
      final question = _questionController.text;
      final guide = await _geminiService.getRepairGuide(partName, question);

      setState(() {
        _repairGuide = guide;
      });
    } catch (e) {
      setState(() {
        _repairGuide = 'Operation failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetView() {
    setState(() {
      _capturedImage = null;
      _recognizedPart = '';
      _repairGuide =
      'Capture a part and ask a question to get your AI repair guide.';
      _questionController.clear();
      _initializeCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCameraReady =
        _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('AI Mechanic Assistant'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetView,
            tooltip: 'Reset and go back to camera',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Camera / Image Preview ---
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                return CameraView(
                  controller: _controller,
                  initializeControllerFuture: _initializeControllerFuture,
                  capturedImage: _capturedImage,
                  recognizedPart: _recognizedPart,
                  isReady: isCameraReady,
                );
              },
            ),
            const SizedBox(height: 20),

            // --- User Input: Question ---
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                labelText: 'What is the problem? (e.g., "why is it leaking?")',
                labelStyle: const TextStyle(color: Colors.blueGrey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon:
                const Icon(Icons.help_outline, color: Colors.blueGrey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.blueGrey),
                  onPressed: _questionController.clear,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 20),

            // --- Capture Button ---
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _captureAndProcess,
              icon: _isLoading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.camera_alt, size: 28),
              label: Text(
                _isLoading ? 'Processing...' : 'Capture & Get Repair Guide',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
              ),
            ),
            const SizedBox(height: 12),

            // --- AR View Button ---
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RepairARScreen()),
              ),
              icon: const Icon(Icons.view_in_ar, size: 28),
              label: const Text(
                'Open AR View',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
              ),
            ),
            const SizedBox(height: 30),

            // --- AI Response Card ---
            ResponseCard(
              title: _recognizedPart.isNotEmpty
                  ? 'AI Repair Guide for: $_recognizedPart'
                  : 'AI Repair Guide',
              content: _repairGuide,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}