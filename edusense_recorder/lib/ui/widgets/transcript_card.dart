import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/transcript.dart';
import 'quiz_badge.dart';
import 'quiz_generator_button.dart';

class TranscriptCard extends StatelessWidget {
  final Transcript transcript;
  final bool hasLocalQuiz;
  final bool isGeneratingQuiz;
  final VoidCallback onDelete;
  final VoidCallback onViewQuiz;
  final VoidCallback onGenerateQuiz;

  const TranscriptCard({
    Key? key,
    required this.transcript,
    required this.hasLocalQuiz,
    required this.isGeneratingQuiz,
    required this.onDelete,
    required this.onViewQuiz,
    required this.onGenerateQuiz,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(transcript.id.toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => onDelete(),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: hasLocalQuiz || transcript.hasQuiz
                ? Colors.blue.shade200
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transcript content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transcript.text.length > 150
                        ? '${transcript.text.substring(0, 150)}...'
                        : transcript.text,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recorded on ${DateFormat('MMM d, y HH:mm').format(transcript.timestamp)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            // Quiz status and actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Quiz badge
                  if (hasLocalQuiz || transcript.hasQuiz)
                    QuizBadge(isLocalQuiz: hasLocalQuiz),
                  
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show loading or generate button
                      if (isGeneratingQuiz)
                        _buildLoadingIndicator()
                      else if (!(hasLocalQuiz || transcript.hasQuiz))
                        QuizGeneratorButton(onPressed: onGenerateQuiz),
                      
                      // View quiz button
                      if (hasLocalQuiz || transcript.hasQuiz)
                        TextButton.icon(
                          icon: Icon(
                            Icons.quiz,
                            color: hasLocalQuiz ? Colors.green : Colors.blue,
                          ),
                          label: Text(
                            'View Quiz',
                            style: TextStyle(
                              color: hasLocalQuiz ? Colors.green : Colors.blue,
                            ),
                          ),
                          onPressed: onViewQuiz,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      children: [
        SizedBox(
          width: 16, 
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Generating quiz...',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
} 