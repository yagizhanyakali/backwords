import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final tempFilesProvider = Provider<TempFiles>((ref) => TempFiles());

/// Owns the app's scratch directory so every recording and reversal can be
/// deleted when it is no longer needed.
class TempFiles {
  static const _dirName = 'backwords';

  Future<Directory> _dir() async {
    final base = await getTemporaryDirectory();
    return Directory('${base.path}/$_dirName').create(recursive: true);
  }

  Future<String> newPath(String prefix) async {
    final dir = await _dir();
    return '${dir.path}/$prefix-${DateTime.now().microsecondsSinceEpoch}.wav';
  }

  Future<void> delete(Iterable<String?> paths) async {
    for (final path in paths) {
      if (path == null) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Best effort: the OS clears the temp directory eventually.
      }
    }
  }

  /// Removes everything left over from earlier runs (crashes, force-quits).
  Future<void> purgeAll() async {
    try {
      final dir = await _dir();
      await for (final entity in dir.list()) {
        await entity.delete(recursive: true);
      }
    } on FileSystemException {
      // Nothing useful to do.
    }
  }
}
