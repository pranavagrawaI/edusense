import 'package:flutter/material.dart';

class QuizGeneratorButton extends StatelessWidget {
  final VoidCallback onPressed;

  const QuizGeneratorButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.auto_awesome, color: Colors.orange),
      label: const Text(
        'Generate Quiz',
        style: TextStyle(color: Colors.orange),
      ),
      onPressed: onPressed,
    );
  }
} 