import 'package:flutter/material.dart';

import 'attachment_thumbnail_stub.dart'
    if (dart.library.io) 'attachment_thumbnail_io.dart';

Widget buildAttachmentThumbnail({
  String? path,
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
  if (path != null) {
    return buildLocalAttachmentThumbnail(path: path, errorBox: errorBox);
  }
  return errorBox;
}
