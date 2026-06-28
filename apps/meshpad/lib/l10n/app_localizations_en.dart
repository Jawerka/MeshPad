// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MeshPad';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get change => 'Change';

  @override
  String get reset => 'Reset';

  @override
  String get clear => 'Clear';

  @override
  String get download => 'Download';

  @override
  String get defaultAction => 'Use default';

  @override
  String get selectFile => 'Choose file';

  @override
  String get changeDataDirTitle => 'Change data folder?';

  @override
  String changeDataDirBody(String path) {
    return 'New folder:\n$path\n\nNotes in the current folder are not moved automatically. Copy them manually if needed.';
  }

  @override
  String dataDirChanged(String path) {
    return 'Data folder: $path';
  }

  @override
  String dataDirChangeFailed(String error) {
    return 'Could not change folder: $error';
  }

  @override
  String get resetDataDirTitle => 'Restore default data folder?';

  @override
  String get resetDataDirBody =>
      'The app will use the standard folder in your user profile again.';

  @override
  String get dataDirReset => 'Data folder reset to default';

  @override
  String get updatesTitle => 'Updates';

  @override
  String updatesUpToDate(String version) {
    return 'You are on the latest version $version';
  }

  @override
  String updatesAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updatesUnavailable => 'Could not check for updates';

  @override
  String get purgeOutboxTitle => 'Clear sync errors?';

  @override
  String get purgeOutboxBody =>
      'Outbox entries with exhausted retries will be removed. Notes on disk are not affected.';

  @override
  String get purgeOutboxNone => 'No failed sync queue entries';

  @override
  String purgeOutboxRemoved(int count) {
    return 'Removed outbox entries: $count';
  }

  @override
  String indexRebuilt(int count) {
    return 'Index rebuilt: $count notes';
  }

  @override
  String errorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get deviceNameTitle => 'Device name';

  @override
  String get deviceNameHint => 'Visible to other devices on the network';

  @override
  String deviceNameSaved(String name) {
    return 'Name: $name';
  }

  @override
  String get apiKeyTitle => 'Server API key';

  @override
  String get apiKeyHint => 'Leave empty if the server has no auth';

  @override
  String get apiKeyNotSet => 'Not set';

  @override
  String get apiKeyMasked => '••••••••';

  @override
  String get apiKeyRemoved => 'API key removed';

  @override
  String get apiKeySaved => 'API key saved';

  @override
  String get apiUrlTitle => 'MeshPad server URL';

  @override
  String get apiUrlLabel => 'Base API URL';

  @override
  String get apiUrlHint => 'http://127.0.0.1:8787';

  @override
  String get exportDialogTitle => 'Export MeshPad notes';

  @override
  String get importArchiveDialogTitle => 'MeshPad archive (.zip)';

  @override
  String apiUrlSaved(String url) {
    return 'Server: $url';
  }

  @override
  String exportNotesCount(int count) {
    return 'Exported notes: $count';
  }

  @override
  String get importNotesTitle => 'Import notes?';

  @override
  String get importNotesBody =>
      'Notes from the archive will be merged with local copies by modification date. The devices/ folder (sync keys) is not imported.';

  @override
  String importNotesResult(int imported, int updated, int skipped) {
    return 'Import: $imported new, $updated updated, $skipped skipped';
  }

  @override
  String get apiServer => 'API server';

  @override
  String get apiKey => 'API key';

  @override
  String get dataFolder => 'Data folder';

  @override
  String get deviceName => 'Device name';

  @override
  String get devicesAndSync => 'Devices & sync';

  @override
  String get syncOutboxErrors => 'Sync queue errors';

  @override
  String syncOutboxErrorsSubtitle(int count) {
    return '$count entries with exhausted retries';
  }

  @override
  String syncSettingsError(String error) {
    return 'Sync settings: $error';
  }

  @override
  String get autoSync => 'Auto-sync';

  @override
  String autoSyncEvery(int minutes) {
    return 'Every $minutes min.';
  }

  @override
  String get autoSyncOff => 'Off';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get themeSection => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get localeSection => 'Language';

  @override
  String get localeRu => 'Russian';

  @override
  String get localeEn => 'English';

  @override
  String get localeSystem => 'System';

  @override
  String get syncTransportSection => 'Sync transport';

  @override
  String get syncTransportLan => 'LAN (HTTP)';

  @override
  String get syncTransportLibp2p => 'libp2p (exp.)';

  @override
  String get syncTransportLanHint =>
      'mDNS + HTTP/HTTPS between trusted devices';

  @override
  String get syncTransportLibp2pHint =>
      'Experimental: localhost sidecar (:45839) wire sync, then LAN fallback';

  @override
  String get exportNotes => 'Export notes';

  @override
  String get exportNotesSubtitle => 'Zip archive of notes/ without sync keys';

  @override
  String get importNotes => 'Import notes';

  @override
  String get importNotesSubtitle => 'Merge by modification date (LWW)';

  @override
  String get autoBackup => 'Scheduled backup';

  @override
  String get autoBackupOff => 'Off';

  @override
  String autoBackupEveryHours(int hours) {
    return 'Every $hours h';
  }

  @override
  String get autoBackupNeedDirectory => 'Choose a folder for zip archives';

  @override
  String get autoBackupDirectory => 'Backup folder';

  @override
  String get autoBackupDirectoryNone => 'Not selected';

  @override
  String get autoBackupPickDirectoryTitle => 'MeshPad backup folder';

  @override
  String autoBackupLastRun(String when) {
    return 'Last backup: $when';
  }

  @override
  String get autoBackupNever => 'No backup yet';

  @override
  String get autoBackupNow => 'Back up now';

  @override
  String get autoBackupNowSubtitle =>
      'Export notes/ to zip in the backup folder';

  @override
  String autoBackupDone(int count) {
    return 'Backup saved ($count notes)';
  }

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String get verifyData => 'Verify data';

  @override
  String get verifyDataSubtitle =>
      'Rebuild index from files, missing thumbnails, and evict cache over limit';

  @override
  String get thumbCacheSection => 'Thumbnail cache';

  @override
  String thumbCacheLimit(int mb) {
    return 'Max cache size: $mb MB';
  }

  @override
  String thumbCacheMb(int mb) {
    return '$mb MB';
  }

  @override
  String get about => 'About';

  @override
  String aboutWeb(String version) {
    return 'MeshPad Web · $version';
  }

  @override
  String aboutNative(String version) {
    return 'MeshPad $version · local-first Markdown';
  }

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get updateDownloadInstall => 'Download and install';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String updateDownloadPercent(int percent) {
    return '$percent%';
  }

  @override
  String updateDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get updateInstallFailed => 'Could not open the installer';

  @override
  String get footerWeb =>
      'Web client connects to the headless server (meshpad_server).';

  @override
  String get footerNative =>
      'Local-first Markdown. Device sync over LAN (HTTP).';

  @override
  String get devicesDiscoveryHint =>
      'Discovery on the local network (mDNS/UDP)';

  @override
  String get devicesManualPeerTitle => 'Manual address';

  @override
  String get devicesManualHostLabel => 'IP or hostname';

  @override
  String get devicesManualPortLabel => 'HTTP port';

  @override
  String get devicesManualProbe => 'Check';

  @override
  String devicesManualProbeOk(String name) {
    return 'Found: $name';
  }

  @override
  String pairingWaitingOn(String device) {
    return 'Waiting for confirmation on $device…';
  }

  @override
  String get pairingQrHostHint =>
      'Scan this QR on the other device (MeshPad mobile)';

  @override
  String get pairingScanQr => 'Scan QR';

  @override
  String get pairingQrScanHint =>
      'Point the camera at the pairing QR on the host device';

  @override
  String get pairingQrInvalid => 'Invalid pairing QR code';

  @override
  String get pairingQrPinMismatch =>
      'PIN in QR does not match the device offer';

  @override
  String get pairingQrProbeFailed =>
      'Could not reach the device from QR. Check Wi‑Fi.';

  @override
  String get devicesSheetTitle => 'Devices';

  @override
  String get devicesTrustedSection => 'Trusted';

  @override
  String get devicesDiscoveredSection => 'Discovered';

  @override
  String get devicesTrustedEmpty =>
      'No trusted devices yet.\nAdd one via PIN pairing.';

  @override
  String get devicesDiscovering =>
      'Searching for devices on the local network…';

  @override
  String get devicesOnLan => 'On local network';

  @override
  String get devicesPinPairing => 'PIN pairing';

  @override
  String get devicesPinShort => 'PIN';

  @override
  String get devicesThisDevice => 'This device';

  @override
  String devicesThisDeviceLan(String host, int port) {
    return 'This device · LAN $host:$port';
  }

  @override
  String devicesThisDevicePort(int port) {
    return 'This device · port $port';
  }

  @override
  String devicesTrustedLan(String host, int port) {
    return 'Trusted · $host:$port';
  }

  @override
  String get devicesTrustedLanUnknown => 'Trusted · LAN unknown';

  @override
  String get devicesIconUpdated => 'Icon updated';

  @override
  String devicesIconUpdatedNamed(String name) {
    return 'Icon for «$name» updated';
  }

  @override
  String get devicesLocalNameTitle => 'This device name';

  @override
  String get devicesLocalNameHint => 'e.g. Work PC';

  @override
  String get devicesTrustedRenameHint => 'Display name in the list';

  @override
  String get devicesNameLabel => 'Name';

  @override
  String devicesTrustedRenamed(String name) {
    return 'Renamed to «$name»';
  }

  @override
  String get devicesPeerUnreachable =>
      'Device is not reachable. Check Wi‑Fi and that MeshPad is open on both devices.';

  @override
  String get devicesSyncTimeout => 'Sync timed out';

  @override
  String devicesSyncNotesCount(int count) {
    return 'Synced notes: $count';
  }

  @override
  String get devicesSyncCompleted => 'Sync completed';

  @override
  String get devicesNoPeersToSync => 'No devices to sync with';

  @override
  String get devicesPairingTitle => 'PIN pairing';

  @override
  String get devicesPairingShowPinSelectPeer =>
      'Show this PIN on the other device. Select a device below to confirm.';

  @override
  String get devicesPairingShowPinOnly => 'Show this PIN on the other device.';

  @override
  String get devicesPairingSelectPeer => 'Device on network';

  @override
  String get devicesRemotePinLabel => 'Other device\'s PIN';

  @override
  String get devicesRemotePinHint => '000000';

  @override
  String get devicesPairingConfirmFailed =>
      'Could not confirm PIN. Check that the device is on the network.';

  @override
  String get devicesPairingNoDiscovered =>
      'No discovered devices. Wait for the list to populate or check Wi‑Fi.';

  @override
  String get devicesPairingNeedWifi =>
      'For PIN pairing both devices must be on the same Wi‑Fi and visible under Discovered.';

  @override
  String get devicesPinInvalid => 'Enter a 6-digit PIN';

  @override
  String get devicesActionIcon => 'Icon';

  @override
  String get devicesActionRename => 'Rename';

  @override
  String get devicesActionSync => 'Sync';

  @override
  String get devicesActionRevoke => 'Revoke trust';

  @override
  String get devicesActionsTooltip => 'Actions';

  @override
  String get devicesManualErrorEmptyHost => 'Enter an IP address or hostname';

  @override
  String get devicesManualErrorInvalidPort => 'Invalid port';

  @override
  String get devicesManualErrorUnreachable =>
      'Device unreachable. Check IP, port, and Wi‑Fi.';

  @override
  String get devicesWebUnsupported => 'Not available in the Web client';

  @override
  String get devicesConfirm => 'Confirm';

  @override
  String get filterAllTags => 'All';

  @override
  String get noteTagsTitle => 'Note tags';

  @override
  String get noteTagsHint => 'work, ideas (comma-separated)';

  @override
  String get noteTagsLabel => 'Tags';

  @override
  String get noteMenuEdit => 'Edit';

  @override
  String get noteMenuTags => 'Tags';

  @override
  String get noteMenuTrash => 'Move to trash';

  @override
  String get noteMenuRestore => 'Restore';

  @override
  String get noteMenuConflicts => 'Conflicting versions';

  @override
  String get noteConflictBadge => 'Conflict';

  @override
  String get noteConflictTitle => 'Conflicting versions';

  @override
  String get noteConflictBody =>
      'Another device edited this note at the same time. Your version is kept; the remote copy is saved separately.';

  @override
  String get noteConflictUntitled => 'Untitled';

  @override
  String get noteConflictPreview => 'Remote version';

  @override
  String get noteConflictClose => 'Close';

  @override
  String get noteConflictUseRemote => 'Use this version';

  @override
  String get noteConflictKeepMine => 'Keep my version';

  @override
  String get noteMenuHistory => 'History';

  @override
  String get noteMenuCopyAll => 'Copy all';

  @override
  String get noteHistoryTitle => 'Version history';

  @override
  String get noteHistoryBody =>
      'Snapshots are saved every 10 local edits (text only; attachments are not rolled back).';

  @override
  String get noteHistoryEmpty =>
      'No snapshots yet. Keep editing — the first snapshot appears at revision 10.';

  @override
  String noteHistoryRevision(int revision) {
    return 'Revision $revision';
  }

  @override
  String get noteHistoryCurrentRevision => 'Matches current revision';

  @override
  String get noteHistoryDiffLegend => 'Diff (− current, + snapshot):';

  @override
  String get noteHistoryRestore => 'Restore';

  @override
  String get noteHistoryClose => 'Close';

  @override
  String get emptyNotePlaceholder => '_Empty note_';
}
