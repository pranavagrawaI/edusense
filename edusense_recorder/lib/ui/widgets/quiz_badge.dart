import 'package:flutter/material.dart';

class LectureBadge extends StatelessWidget {
  final bool isLocalLecture;

  const LectureBadge({
    super.key,
    required this.isLocalLecture,
  });

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
            color: isLocalLecture ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            'Lecture Available',
            style: TextStyle(
              fontSize: 12,
              color: isLocalLecture ? Colors.green : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 