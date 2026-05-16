import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'main.dart' show DriverScreen;

void main() {
  runApp(const KarrytDriverApp());
}

class KarrytDriverApp extends StatelessWidget {
  const KarrytDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karryt Chofer',
      theme: buildKarrytTheme(KarrytRoleTheme.driver),
      home: const DriverScreen(),
    );
  }
}
