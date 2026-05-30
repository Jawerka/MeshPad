import 'dart:io';

import 'package:flutter/material.dart';

Widget buildLightboxImage(String source) {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return Image.network(source, fit: BoxFit.contain);
  }
  return Image.file(File(source), fit: BoxFit.contain);
}
