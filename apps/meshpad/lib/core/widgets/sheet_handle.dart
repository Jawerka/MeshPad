import 'package:flutter/material.dart';

import '../theme/meshpad_colors.dart';

/// Drag handle for modal bottom sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: MeshPadColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
