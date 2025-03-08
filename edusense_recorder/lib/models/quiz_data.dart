import 'quiz.dart';

class QuizData {
  final int transcriptId;
  final List<Quiz> questions;
  final DateTime createdAt;

  QuizData({
    required this.transcriptId,
    required this.questions,
    required this.createdAt,
  });

  factory QuizData.fromJson(Map<String, dynamic> json) {
    return QuizData(
      transcriptId: json['transcript_id'],
      questions: (json['questions'] as List)
          .map((q) => Quiz.fromJson(q))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcript_id': transcriptId,
      'questions': questions.map((q) => q.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
} 