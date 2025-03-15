import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transcript.dart';
import 'quiz_badge.dart';
import 'quiz_generator_button.dart';

class TranscriptCard extends StatelessWidget {
  final Transcript transcript;
  final bool hasLocalMiniLecture;
  final bool isGeneratingMiniLecture;
  final VoidCallback onDelete;
  final VoidCallback onViewMiniLecture;
  final VoidCallback onGenerateMiniLecture;

  const TranscriptCard({
    super.key,
    required this.transcript,
    required this.hasLocalMiniLecture,
    required this.isGeneratingMiniLecture,
    required this.onDelete,
    required this.onViewMiniLecture,
    required this.onGenerateMiniLecture,
  });

  @override
  Widget build(BuildContext context) {
    // Use the helper to get the truncated text
    final truncatedText = truncateTextByWords(transcript.text, 5);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasLocalMiniLecture || transcript.hasMiniLecture
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
                // Display only the first 5 words plus "..."
                Text(
                  truncatedText,
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
                if (hasLocalMiniLecture || transcript.hasMiniLecture)
                  LectureBadge(isLocalLecture: hasLocalMiniLecture),
                  
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show loading indicator or generate quiz button
                    if (isGeneratingMiniLecture)
                      _buildLoadingIndicator()
                    else if (!(hasLocalMiniLecture || transcript.hasMiniLecture))
                      QuizGeneratorButton(onPressed: onGenerateMiniLecture),
                      
                    // View quiz button
                    if (hasLocalMiniLecture || transcript.hasMiniLecture)
                      TextButton.icon(
                        icon: Icon(
                          Icons.quiz,
                          color: hasLocalMiniLecture ? Colors.green : Colors.blue,
                        ),
                        label: Text(
                          'View Quiz',
                          style: TextStyle(
                            color: hasLocalMiniLecture ? Colors.green : Colors.blue,
                          ),
                        ),
                        onPressed: onViewMiniLecture,
                      ),
                      
                    // Delete button with confirmation dialog
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to show a confirm dialog before deleting
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content:
              const Text('Are you sure you want to delete this transcript?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Generating mini-lecture...',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// Truncate text at the specified word limit
String truncateTextByWords(String text, int wordLimit) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= wordLimit) {
    return text; // or words.join(' ')
  }
  return '${words.take(wordLimit).join(' ')}...';
}
