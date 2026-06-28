import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search field visibility in feed header (desktop shortcuts sync here).
final feedSearchOpenProvider = StateProvider<bool>((ref) => false);

/// Increment to request composer focus (PLAN §11.9.4 Ctrl+N).
final feedComposerFocusRequestProvider = StateProvider<int>((ref) => 0);

/// Increment to open settings sheet (Ctrl+K).
final feedSettingsOpenRequestProvider = StateProvider<int>((ref) => 0);
