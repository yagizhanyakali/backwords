import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/audio/temp_files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Clear anything a previous run (crash, force-quit) left behind.
  await TempFiles().purgeAll();
  runApp(const ProviderScope(child: BackwordsApp()));
}
