import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transcript.dart';
import 'quiz_badge.dart';

class TranscriptCard extends StatelessWidget {
  final Transcript transcript;
  final bool hasLocalMiniLecture;
  final bool isGeneratingMiniLecture;
  final VoidCallback onViewMiniLecture;

  const TranscriptCard({
    super.key,
    required this.transcript,
    required this.hasLocalMiniLecture,
    required this.isGeneratingMiniLecture,
    required this.onViewMiniLecture,
  });

  @override
  Widget build(BuildContext context) {
    final truncatedText = truncateTextByWords(transcript.text, 5);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              hasLocalMiniLecture || transcript.hasMiniLecture
                  ? Colors.blue.shade200
                  : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(truncatedText, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Recorded on ${DateFormat('MMM d, y HH:mm').format(transcript.timestamp)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hasLocalMiniLecture || transcript.hasMiniLecture)
                  LectureBadge(isLocalLecture: hasLocalMiniLecture),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasLocalMiniLecture || transcript.hasMiniLecture)
                      TextButton.icon(
                        icon: Icon(
                          Icons.quiz,
                          color:
                              hasLocalMiniLecture ? Colors.green : Colors.blue,
                        ),
                        label: Text(
                          'View Lecture',
                          style: TextStyle(
                            color:
                                hasLocalMiniLecture
                                    ? Colors.green
                                    : Colors.blue,
                          ),
                        ),
                        onPressed: onViewMiniLecture,
                      ) 
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String truncateTextByWords(String text, int wordLimit) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= wordLimit) {
    return text;
  }
  return '${words.take(wordLimit).join(' ')}...';
}
