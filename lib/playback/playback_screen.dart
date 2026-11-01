import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_clip.dart';
import '../core/audio/temp_files.dart';
import 'player_panel.dart';
import 'playback_controller.dart';

/// Plays a freshly recorded clip backwards. Owns the clip's temp files and
/// deletes them when the screen closes.
class PlaybackScreen extends ConsumerStatefulWidget {
  const PlaybackScreen({super.key, required this.pair});

  final ClipPair pair;

  @override
  ConsumerState<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends ConsumerState<PlaybackScreen> {
  late final TempFiles _temp;

  @override
  void initState() {
    super.initState();
    _temp = ref.read(tempFilesProvider);
  }

  @override
  void dispose() {
    _temp.delete(widget.pair.paths);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backwards!')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              PlayerPanel(
                args: PlaybackArgs(widget.pair),
                title: 'Your clip',
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Record another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
