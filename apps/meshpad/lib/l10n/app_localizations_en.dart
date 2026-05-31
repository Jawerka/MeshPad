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
      'Sidecar on :45839; sync still uses LAN fallback';

  @override
  String get exportNotes => 'Export notes';

  @override
  String get exportNotesSubtitle => 'Zip archive of notes/ without sync keys';

  @override
  String get importNotes => 'Import notes';

  @override
  String get importNotesSubtitle => 'Merge by modification date (LWW)';

  @override
  String get verifyData => 'Verify data';

  @override
  String get verifyDataSubtitle =>
      'Rebuild index from files and missing thumbnails';

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
  String get footerWeb =>
      'Web client connects to the headless server (meshpad_server).';

  @override
  String get footerNative =>
      'Local-first Markdown. Device sync over LAN (HTTP).';

  @override
  String get devicesDiscoveryHint =>
      'Discovery on the local network (mDNS/UDP)';

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
  String get emptyNotePlaceholder => '_Empty note_';
}
