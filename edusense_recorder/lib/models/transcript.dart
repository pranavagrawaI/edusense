class Transcript {
  final int id;
  final String text;
  final DateTime timestamp;
  final bool hasMiniLecture;

  Transcript({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.hasMiniLecture,
  });

  factory Transcript.fromJson(Map<String, dynamic> json) {
    return Transcript(
      id: json['id'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      hasMiniLecture: json['has_mini_lecture'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'has_mini_lecture': hasMiniLecture,
    };
  }

  // Create a copy with modified values
  Transcript copyWith({
    int? id,
    String? text,
    DateTime? timestamp,
    bool? hasMiniLecture,
  }) {
    return Transcript(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      hasMiniLecture: hasMiniLecture ?? this.hasMiniLecture,
    );
  }
}
