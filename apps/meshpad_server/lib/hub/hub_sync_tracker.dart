import 'package:meshpad_p2p/meshpad_p2p.dart';

/// Recent hub sync / pairing activity for the web dashboard.
class HubSyncTracker {
  static const maxEvents = 20;

  LanSyncRunResult? lastResult;
  DateTime? lastSyncAt;
  bool syncInProgress = false;
  final events = <HubSyncEvent>[];

  void recordStarted() {
    syncInProgress = true;
    _push(HubSyncEvent(
      at: DateTime.now().toUtc(),
      kind: HubSyncEventKind.started,
      message: 'Синхронизация началась',
    ));
  }

  void recordResult(LanSyncRunResult result, {Map<String, String>? peerNames}) {
    syncInProgress = false;
    lastResult = result;
    lastSyncAt = DateTime.now().toUtc();

    final names = peerNames ?? const {};
    final message = _messageFor(result, names);
    _push(HubSyncEvent(
      at: lastSyncAt!,
      kind: _kindFor(result.status),
      message: message,
      noteCount: result.noteCount,
      succeededPeerIds: result.succeededPeerIds,
      failedPeerIds: result.failedPeerIds,
    ));
  }

  void recordPairing({required String deviceName}) {
    _push(HubSyncEvent(
      at: DateTime.now().toUtc(),
      kind: HubSyncEventKind.pairing,
      message: 'Подключено устройство: $deviceName',
    ));
  }

  void _push(HubSyncEvent event) {
    events.insert(0, event);
    if (events.length > maxEvents) {
      events.removeRange(maxEvents, events.length);
    }
  }

  static HubSyncEventKind _kindFor(LanSyncRunStatus status) {
    return switch (status) {
      LanSyncRunStatus.completed => HubSyncEventKind.completed,
      LanSyncRunStatus.partial => HubSyncEventKind.partial,
      LanSyncRunStatus.failed => HubSyncEventKind.failed,
      LanSyncRunStatus.noPeers => HubSyncEventKind.noPeers,
    };
  }

  static String _messageFor(
    LanSyncRunResult result,
    Map<String, String> peerNames,
  ) {
    final notes = result.noteCount;
    final notePhrase = switch (notes) {
      0 => 'всё актуально',
      1 => '1 заметка',
      _ => '$notes заметок',
    };

    return switch (result.status) {
      LanSyncRunStatus.completed => 'Успешно — $notePhrase',
      LanSyncRunStatus.partial => () {
          final failed = result.failedPeerIds
              .map((id) => peerNames[id] ?? id.substring(0, 8))
              .join(', ');
          return 'Частично — $notePhrase; недоступно: $failed';
        }(),
      LanSyncRunStatus.failed => result.message ?? 'Ошибка синхронизации',
      LanSyncRunStatus.noPeers => 'Нет доверенных устройств',
    };
  }
}

enum HubSyncEventKind {
  started,
  completed,
  partial,
  failed,
  noPeers,
  pairing,
}

class HubSyncEvent {
  const HubSyncEvent({
    required this.at,
    required this.kind,
    required this.message,
    this.noteCount,
    this.succeededPeerIds = const [],
    this.failedPeerIds = const [],
  });

  final DateTime at;
  final HubSyncEventKind kind;
  final String message;
  final int? noteCount;
  final List<String> succeededPeerIds;
  final List<String> failedPeerIds;

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'kind': kind.name,
        'message': message,
        if (noteCount != null) 'note_count': noteCount,
        if (succeededPeerIds.isNotEmpty) 'succeeded_peer_ids': succeededPeerIds,
        if (failedPeerIds.isNotEmpty) 'failed_peer_ids': failedPeerIds,
      };
}
