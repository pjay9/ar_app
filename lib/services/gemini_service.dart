import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class GeminiService {
  final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${ApiConfig.geminiApiKey}';

  // Existing method - unchanged
  Future<String> getRepairGuide(String partName, String userQuestion) async {
    final systemPrompt =
        "You are a professional, expert mechanic. Your response must be direct, clear, and focused on practical steps. You MUST refer to the recognized part by name and highlight it in **bold** to draw attention to the location of the fix.";
    final userPrompt =
        "The user is looking at the '$partName'. The user is asking: '$userQuestion'. Provide a detailed, step-by-step guide on how to address their question related to the component shown.";

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": userPrompt}
          ]
        }
      ],
      "systemInstruction": {
        "parts": [{"text": systemPrompt}]
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Network error: $e";
    }
  }

  // NEW method - sends image to Gemini, gets back bounding boxes
  Future<List<DetectedObject>> detectParts(File imageFile) async {

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final prompt = """
Analyze this image of a car engine or mechanical parts.
Detect all visible car parts/components.
Return ONLY a JSON array, no markdown, no explanation. Example format:
[
  {"label": "air filter", "confidence": 0.95, "left": 0.1, "top": 0.2, "right": 0.5, "bottom": 0.6},
  {"label": "battery", "confidence": 0.88, "left": 0.55, "top": 0.1, "right": 0.9, "bottom": 0.5}
]
All coordinate values must be between 0.0 and 1.0 (relative to image size).
If no car parts are detected, return an empty array: []
""";

    final payload = {
      "contents": [
        {
          "parts": [
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image,
              }
            },
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.1, // low temp for consistent structured output
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['candidates'][0]['content']['parts'][0]['text'];

        // Strip any markdown code fences if Gemini adds them
        text = text.replaceAll(RegExp(r'```json|```'), '').trim();

        final List<dynamic> parsed = jsonDecode(text);
        return parsed.map((e) => DetectedObject.fromJson(e)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}

class DetectedObject {
  final String label;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      label: json['label'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      left: (json['left'] ?? 0.0).toDouble(),
      top: (json['top'] ?? 0.0).toDouble(),
      right: (json['right'] ?? 1.0).toDouble(),
      bottom: (json['bottom'] ?? 1.0).toDouble(),
    );
  }
}