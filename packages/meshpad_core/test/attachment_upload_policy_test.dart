import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('allows known image extension', () {
    expect(
      () => validateAttachmentUpload(
        fileName: 'photo.jpg',
        byteLength: 1024,
      ),
      returnsNormally,
    );
  });

  test('rejects disallowed extension', () {
    expect(
      () => validateAttachmentUpload(
        fileName: 'malware.exe',
        byteLength: 10,
      ),
      throwsA(isA<AttachmentUploadRejectedException>()),
    );
  });

  test('rejects oversize upload', () {
    expect(
      () => validateAttachmentUpload(
        fileName: 'big.jpg',
        byteLength: attachmentUploadMaxBytes + 1,
      ),
      throwsA(
        predicate<AttachmentUploadRejectedException>(
          (e) => e.code == 'too_large',
        ),
      ),
    );
  });
}
