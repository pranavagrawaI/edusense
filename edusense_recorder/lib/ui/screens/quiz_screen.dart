import 'package:flutter/material.dart';
import 'dart:convert';

import '../../config/app_config.dart';
import '../../models/quiz.dart';
import '../../models/quiz_data.dart';
import '../../services/api/quiz_api.dart';
import '../../services/storage/quiz_storage.dart';

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
    _loadOrGenerateQuiz();
  }

  Future<void> _loadOrGenerateQuiz() async {
    setState(() {
      isLoading = true;
    });

    // Try to load stored quiz first
    final storedQuiz = await QuizStorage.loadQuiz(widget.transcriptId);
    if (storedQuiz != null) {
      setState(() {
        quizzes = storedQuiz.questions;
        isLoading = false;
      });
      return;
    }

    // Generate new quiz if none exists
    await _generateQuiz();
  }

  Future<void> _generateQuiz() async {
    try {
      final response = await QuizApi.generateQuiz(widget.transcriptId);

      if (response.success && response.data != null) {
        final quizData = response.data!['quiz_data'];
        final questionsList = (quizData['questions'] as List);
        
        final generatedQuizzes = questionsList
            .map((q) => Quiz.fromJson(q as Map<String, dynamic>))
            .toList();

        // Save the generated quiz
        await QuizStorage.saveQuiz(widget.transcriptId, generatedQuizzes);

        setState(() {
          quizzes = generatedQuizzes;
          isLoading = false;
        });
      } else {
        throw Exception(response.error ?? 'Failed to generate quiz');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating quiz: $e')),
      );
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
                  return _buildQuizCard(quiz, index);
                },
              ),
    );
  }
  
  Widget _buildQuizCard(Quiz quiz, int index) {
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
              _buildResultsFeedback(quiz, index),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultsFeedback(Quiz quiz, int index) {
    final isCorrect = selectedAnswers[index] == quiz.correctAnswer;
    
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? '✅ Correct!' : '❌ Incorrect',
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
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
    );
  }
} 