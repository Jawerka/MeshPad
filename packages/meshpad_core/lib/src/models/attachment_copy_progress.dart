/// Progress while copying an attachment into a note folder.
class AttachmentCopyProgress {
  const AttachmentCopyProgress({
    required this.fileName,
    required this.copiedBytes,
    required this.totalBytes,
    this.fileIndex = 1,
    this.fileCount = 1,
  });

  final String fileName;
  final int copiedBytes;
  final int totalBytes;
  final int fileIndex;
  final int fileCount;

  double get fraction =>
      totalBytes > 0 ? copiedBytes / totalBytes : 0;

  bool get isIndeterminate => totalBytes <= 0;
}

typedef AttachmentCopyProgressCallback = void Function(
  AttachmentCopyProgress progress,
);
