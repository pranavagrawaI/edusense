class Topic {
  final String topic;
  final String definition;
  final List<String> insights;

  Topic({
    required this.topic,
    required this.definition,
    required this.insights,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      topic: json['topic'],
      definition: json['definition'],
      insights: List<String>.from(json['insights']),
    );
  }
}

class MCQ {
  final String question;
  final Map<String, String> options;
  final String correctAnswer;
  final String explanation;

  MCQ({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory MCQ.fromJson(Map<String, dynamic> json) {
    return MCQ(
      question: json['question'],
      options: Map<String, String>.from(json['options']),
      correctAnswer: json['correct_answer'],
      explanation: json['explanation'],
    );
  }
}
