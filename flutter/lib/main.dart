import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/map/map_screen.dart';

void main() {
  runApp(const ProviderScope(child: RouteBuilderApp()));
}

class RouteBuilderApp extends StatelessWidget {
  const RouteBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Route Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3b82f6),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
