import 'dart:io';

import 'package:flutter/material.dart';

Widget buildLocalAttachmentThumbnail({
  required String path,
  required Widget errorBox,
}) {
  return Image.file(
    File(path),
    width: 120,
    height: 120,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => errorBox,
  );
}
