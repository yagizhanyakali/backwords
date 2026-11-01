import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

// TODO(m4a-export): v1 shares the reversed clip as WAV. Add m4a (AAC) export
// through a platform channel (AVAssetExportSession on iOS, MediaCodec/
// MediaMuxer on Android), with no FFmpeg dependency. Encode the reversed WAV
// to a temp .m4a, then pass that file to [shareClip] with mimeType audio/mp4.

/// Opens the system share sheet with the WAV at [path].
///
/// [origin] anchors the popover on iPad; pass the share button's bounds.
Future<void> shareClip(String path, {Rect? origin}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: 'audio/wav')],
      text: 'Made with Backwords',
      sharePositionOrigin: origin,
    ),
  );
}

/// The on-screen rectangle of the widget behind [context], for [shareClip].
Rect? originOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
