import 'package:flutter/material.dart';

import 'router.dart';

class GenbaNoteApp extends StatelessWidget {
  const GenbaNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '現場ノート',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C6E4A)),
        fontFamily: 'NotoSansJP',
        useMaterial3: true,
      ),
    );
  }
}
