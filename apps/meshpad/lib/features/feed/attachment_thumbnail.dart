import 'package:flutter/material.dart';

import 'attachment_thumbnail_stub.dart'
    if (dart.library.io) 'attachment_thumbnail_io.dart';

Widget buildAttachmentThumbnail({
  String? path,
  String? thumbPath,
  String? url,
  required Widget errorBox,
}) {
  if (url != null) {
    return Image.network(
      url,
      width: 120,
      height: 120,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => errorBox,
    );
  }
  final localPath = thumbPath ?? path;
  if (localPath != null) {
    return buildLocalAttachmentThumbnail(path: localPath, errorBox: errorBox);
  }
  return errorBox;
}
