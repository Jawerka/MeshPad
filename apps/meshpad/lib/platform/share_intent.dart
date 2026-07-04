import 'package:flutter/services.dart';

/// Payload from Android share intent (Sprint 5).
class SharePayload {
  const SharePayload({
    required this.type,
    this.text,
    this.filePath,
    this.filePaths = const [],
    this.mimeType,
  });

  final String type;
  final String? text;
  final String? filePath;
  final List<String> filePaths;
  final String? mimeType;

  bool get isText => type == 'text';
  bool get isFile => type == 'file';
  bool get isFiles => type == 'files';

  List<String> get resolvedFilePaths {
    if (filePaths.isNotEmpty) return filePaths;
    if (filePath != null && filePath!.isNotEmpty) return [filePath!];
    return const [];
  }

  factory SharePayload.fromMap(Map<dynamic, dynamic> map) {
    final rawPaths = map['filePaths'];
    final paths = switch (rawPaths) {
      List<dynamic> list =>
        list.map((entry) => entry.toString()).where((p) => p.isNotEmpty).toList(),
      _ => const <String>[],
    };

    return SharePayload(
      type: map['type'] as String? ?? 'text',
      text: map['text'] as String?,
      filePath: map['filePath'] as String?,
      filePaths: paths,
      mimeType: map['mimeType'] as String?,
    );
  }
}

class ShareIntentPlatform {
  ShareIntentPlatform._();

  static const _methodChannel = MethodChannel('com.meshpad/share');
  static const _eventChannel = EventChannel('com.meshpad/share_events');

  static Future<SharePayload?> getInitialShare() async {
    final map = await _methodChannel.invokeMethod<Map<dynamic, dynamic>?>(
      'getInitialShare',
    );
    if (map == null) return null;
    return SharePayload.fromMap(map);
  }

  static Stream<SharePayload> get shareStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return SharePayload.fromMap(event as Map<dynamic, dynamic>);
    });
  }
}
