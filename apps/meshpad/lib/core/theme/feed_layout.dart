import 'package:flutter/material.dart';

import 'meshpad_colors.dart';

bool isCompactFeedLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width < 720;
}

double feedBubbleMaxWidth(BuildContext context) {
  if (isCompactFeedLayout(context)) {
    return MediaQuery.sizeOf(context).width;
  }
  return MeshPadColors.chatMaxWidth;
}
