import 'package:flutter/material.dart';

class QuizGeneratorButton extends StatelessWidget {
  final VoidCallback onPressed;

  const QuizGeneratorButton({
    super.key,
    required this.onPressed,
  });

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