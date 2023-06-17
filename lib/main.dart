import 'package:flutter/material.dart';
import 'package:pictionary/screens/home_screen.dart';
import 'package:pictionary/screens/paint_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pictionary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xffe5ece9),
          scaffoldBackgroundColor: const Color(0xffe5ece9),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
              backgroundColor:
                  MaterialStateProperty.all(const Color(0xFFc60f7b)),
              textStyle: MaterialStateProperty.all(
                const TextStyle(color: Colors.white),
              ),
            ),
          )),
      home: const HomeScreen(),
    );
  }
}
