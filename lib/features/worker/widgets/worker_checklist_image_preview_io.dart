import 'dart:io';

import 'package:flutter/material.dart';

/// Mobil: HTTP nebo lokální soubor z offline kopie.
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
  final f = File(s);
  if (f.existsSync()) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        f,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }
  // PROČ: Cesta v Driftu bez existujícího souboru (smazaná kopie, migrace) – neutvrzujeme úspěch falešnou fajfkou.
  return Icon(Icons.broken_image_outlined, color: Colors.grey.shade600, size: 28);
}
