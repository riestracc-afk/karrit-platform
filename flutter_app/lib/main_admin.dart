import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'main.dart' show AdminScreen;

void main() {
  runApp(const KarrytAdminApp());
}

class KarrytAdminApp extends StatelessWidget {
  const KarrytAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karryt Admin PC',
      theme: buildKarrytTheme(KarrytRoleTheme.admin),
      home: const _AdminDesktopFrame(),
    );
  }
}

class _AdminDesktopFrame extends StatelessWidget {
  const _AdminDesktopFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: const AdminScreen(),
      ),
    );
  }
}
