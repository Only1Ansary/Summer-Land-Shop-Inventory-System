import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'ui/app_theme.dart';

void main() {
  runApp(const SummerlandApp());
}

class SummerlandApp extends StatelessWidget {
  const SummerlandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Summerland',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}