class Quiz {
  final String question;
  final Map<String, String> options;
  final String correctAnswer;
  final String explanation;

  Quiz({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      question: json['question'],
      options: Map<String, String>.from(json['options']),
      correctAnswer: json['correct_answer'],
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
    };
  }
} 