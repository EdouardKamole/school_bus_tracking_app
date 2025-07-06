// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/student_home_screen.dart';

void main() {
  runApp(BechBusApp());
}

class BechBusApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bech Bus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      home: StudentHomeScreen(studentName: 'Mohammed Ali'),
      debugShowCheckedModeBanner: false,
    );
  }
}