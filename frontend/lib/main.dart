import 'package:flutter/material.dart';

import 'features/auth/presentation/screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      title: 'Rovolo EdTech',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        brightness: Brightness.light,

        primaryColor: const Color(0xFF2563EB),

        scaffoldBackgroundColor: Colors.white,

        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF1D4ED8),
          error: Color(0xFFEF4444),
        ),

        useMaterial3: true,
      ),

      // START APP FROM LOGIN
      home: const LoginScreen(),
    );
  }
}