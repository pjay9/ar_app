// lib/widgets/response_card.dart
import 'package:flutter/material.dart';

class ResponseCard extends StatelessWidget {
  final String title;
  final String content;

  const ResponseCard({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.shade100, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            const Divider(height: 20, thickness: 1),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}