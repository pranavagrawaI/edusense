class Transcript {
  final int id;
  final String text;
  final DateTime timestamp;
  final bool hasQuiz;

  Transcript({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.hasQuiz,
  });

  factory Transcript.fromJson(Map<String, dynamic> json) {
    return Transcript(
      id: json['id'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      hasQuiz: json['has_quiz'],
    );
  }
} 