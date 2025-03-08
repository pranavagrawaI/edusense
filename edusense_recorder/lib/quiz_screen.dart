import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
}

class QuizScreen extends StatefulWidget {
  final int transcriptId;

  const QuizScreen({super.key, required this.transcriptId});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Quiz> quizzes = [];
  bool isLoading = false;
  Map<int, String> selectedAnswers = {};
  bool showResults = false;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
  }

  Future<void> _generateQuiz() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.29.33:5000/generate_quiz/${widget.transcriptId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quizData = json.decode(data['quiz_data']);

        setState(() {
          quizzes =
              (quizData['questions'] as List)
                  .map((q) => Quiz.fromJson(q))
                  .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to generate quiz');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating quiz: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture Quiz'),
        actions: [
          if (quizzes.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  showResults = !showResults;
                });
              },
              child: Text(
                showResults ? 'Hide Results' : 'Show Results',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = quizzes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question ${index + 1}:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(quiz.question),
                          const SizedBox(height: 16),
                          ...quiz.options.entries.map(
                            (option) => RadioListTile<String>(
                              title: Text(option.value),
                              value: option.key,
                              groupValue: selectedAnswers[index],
                              onChanged: (value) {
                                setState(() {
                                  selectedAnswers[index] = value!;
                                });
                              },
                            ),
                          ),
                          if (showResults && selectedAnswers.containsKey(index))
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedAnswers[index] == quiz.correctAnswer
                                        ? '✅ Correct!'
                                        : '❌ Incorrect',
                                    style: TextStyle(
                                      color:
                                          selectedAnswers[index] ==
                                                  quiz.correctAnswer
                                              ? Colors.green
                                              : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Explanation: ${quiz.explanation}',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
