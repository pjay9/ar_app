// lib/widgets/camera_view.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraView extends StatelessWidget {
  final CameraController? controller;
  final Future<void>? initializeControllerFuture;
  final XFile? capturedImage;
  final String recognizedPart;
  final bool isReady;

  const CameraView({
    super.key,
    required this.controller,
    required this.initializeControllerFuture,
    required this.capturedImage,
    required this.recognizedPart,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Display Camera Preview or Captured Image
            if (isReady && controller != null)
              _buildImageOrCamera(context),

            // 2. Loading Indicator for Camera Init
            if (!isReady)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // 3. Overlay for Recognized Part Status
            if (recognizedPart.isNotEmpty)
              _buildPartOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOrCamera(BuildContext context) {
    if (capturedImage != null) {
      return Image.file(
        File(capturedImage!.path),
        fit: BoxFit.cover,
      );
    } else if (controller!.value.isInitialized) {
      // Use the CameraPreview with AspectRatio to prevent stretching
      return AspectRatio(
        aspectRatio: controller!.value.aspectRatio,
        child: CameraPreview(controller!),
      );
    }
    return const Center(
        child: Text("Camera Error", style: TextStyle(color: Colors.white)));
  }

  Widget _buildPartOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Text(
          'Recognized: $recognizedPart',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}