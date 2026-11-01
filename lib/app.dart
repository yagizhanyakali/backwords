import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'record/record_screen.dart';

class BackwordsApp extends StatelessWidget {
  const BackwordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backwords',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      home: const RecordScreen(),
    );
  }
}
