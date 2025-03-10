class MiniLecture {
  final String abstract;
  final List<KeyTopic> keyTopics;
  final List<MCQ> mcqs;

  MiniLecture({
    required this.abstract,
    required this.keyTopics,
    required this.mcqs,
  });

  Map<String, dynamic> toJson() {
    return {
      'abstract': abstract,
      'key_topics': keyTopics.map((topic) => topic.toJson()).toList(),
      'mcqs': mcqs.map((q) => q.toJson()).toList(),
    };
  }

  factory MiniLecture.fromJson(Map<String, dynamic> json) {
    return MiniLecture(
      abstract: json['abstract'],
      keyTopics:
          (json['key_topics'] as List)
              .map((topic) => KeyTopic.fromJson(topic))
              .toList(),
      mcqs: (json['mcqs'] as List).map((q) => MCQ.fromJson(q)).toList(),
    );
  }
}

class KeyTopic {
  final String topic;
  final String definition;
  final List<String> insights;

  KeyTopic({
    required this.topic,
    required this.definition,
    required this.insights,
  });

  factory KeyTopic.fromJson(Map<String, dynamic> json) {
    return KeyTopic(
      topic: json['topic'] ?? '',
      definition: json['definition'] ?? '',
      insights:
          (json['insights'] as List<dynamic>)
              .map((item) => item.toString())
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'topic': topic, 'definition': definition, 'insights': insights};
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
      question: json['question'] ?? '',
      options: Map<String, String>.from(json['options'] ?? {}),
      correctAnswer: json['correct_answer'] ?? '',
      explanation: json['explanation'] ?? '',
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
