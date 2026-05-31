import 'package:crypto/crypto.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('attachmentBytesMatch checks size and sha256', () {
    final bytes = [97, 98, 99];
    final meta = AttachmentMeta(
      name: 'file.bin',
      size: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );

    expect(attachmentBytesMatch([1, 2, 3], meta), isFalse);
    expect(attachmentBytesMatch(bytes, meta), isTrue);
  });

  test('attachmentBytesMatch accepts size-only when sha256 absent', () {
    const meta = AttachmentMeta(name: 'file.bin', size: 2);
    expect(attachmentBytesMatch([1, 2], meta), isTrue);
    expect(attachmentBytesMatch([1], meta), isFalse);
  });
}
