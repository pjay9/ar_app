// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/mechanic_home_page.dart';

void main() {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp`.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MechanicApp());
}

class MechanicApp extends StatelessWidget {
  const MechanicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Mechanic Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const MechanicHomePage(),
    );
  }
}