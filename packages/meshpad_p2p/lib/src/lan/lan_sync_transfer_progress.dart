/// Reports byte progress while syncing attachments over LAN HTTP.
class LanSyncTransferProgress {
  LanSyncTransferProgress({this.onProgress});

  void Function(String fileName, int transferred, int total)? onProgress;

  void report({
    required String fileName,
    required int transferred,
    required int total,
  }) {
    onProgress?.call(fileName, transferred, total);
  }
}

/// Shared hook wired from the Flutter app during sync.
final lanSyncTransferProgress = LanSyncTransferProgress();
