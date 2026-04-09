import 'package:flutter/material.dart';

/// Web: pouze síťové URL (žádný dart:io).
Widget buildWorkerChecklistImagePreview(String urlOrPath) {
  final s = urlOrPath.trim();
  if (s.isEmpty) return const SizedBox.shrink();
  if (s.startsWith('http')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        s,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
      ),
    );
  }
  return Icon(Icons.check_circle, color: Colors.green.shade700, size: 28);
}
