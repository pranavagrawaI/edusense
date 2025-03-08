import 'package:flutter/material.dart';

class QuizBadge extends StatelessWidget {
  final bool isLocalQuiz;

  const QuizBadge({
    Key? key,
    required this.isLocalQuiz,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.quiz,
            size: 16,
            color: isLocalQuiz ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            'Quiz Available',
            style: TextStyle(
              fontSize: 12,
              color: isLocalQuiz ? Colors.green : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 