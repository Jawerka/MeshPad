import 'package:flutter/material.dart';

Widget buildLightboxImage(String source) {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return Image.network(source, fit: BoxFit.contain);
  }
  return const Icon(Icons.broken_image_outlined,
      color: Colors.white54, size: 64);
}
