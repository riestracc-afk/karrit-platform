import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'main.dart' show RideScreen;

void main() {
  runApp(const KarrytUserApp());
}

class KarrytUserApp extends StatelessWidget {
  const KarrytUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karryt Mueve',
      theme: buildKarrytTheme(KarrytRoleTheme.user),
      home: const RideScreen(),
    );
  }
}
