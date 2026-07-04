import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

AttachmentMeta meta(String name, {String? mime}) =>
    AttachmentMeta(name: name, size: 1, mime: mime);

void main() {
  test('attachmentPreviewKind detects video and audio', () {
    expect(
        attachmentPreviewKind(meta('clip.mp4')), AttachmentPreviewKind.video);
    expect(
        attachmentPreviewKind(meta('clip.MOV')), AttachmentPreviewKind.video);
    expect(
        attachmentPreviewKind(meta('song.mp3')), AttachmentPreviewKind.audio);
    expect(
        attachmentPreviewKind(meta('voice.m4a')), AttachmentPreviewKind.audio);
    expect(attachmentPreviewKind(meta('pic.png')), AttachmentPreviewKind.image);
    expect(attachmentPreviewKind(meta('doc.pdf')), AttachmentPreviewKind.file);
  });

  test('attachmentPreviewKind respects explicit mime', () {
    expect(
      attachmentPreviewKind(meta('x.bin', mime: 'video/webm')),
      AttachmentPreviewKind.video,
    );
    expect(
      attachmentPreviewKind(meta('x.bin', mime: 'audio/ogg')),
      AttachmentPreviewKind.audio,
    );
  });
}
