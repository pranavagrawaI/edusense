import 'package:flutter/material.dart';

import 'ui/screens/transcript_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const UserApp());
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduSense',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TranscriptHistoryScreen(),
    );
  }
}
