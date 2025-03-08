import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../models/quiz_data.dart';
import '../../models/quiz.dart';

class QuizStorage {
  // Save a quiz to local storage
  static Future<bool> saveQuiz(int transcriptId, List<Quiz> questions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quizData = QuizData(
        transcriptId: transcriptId,
        questions: questions,
        createdAt: DateTime.now(),
      );
      
      await prefs.setString(
        AppConfig.quizKey(transcriptId),
        json.encode(quizData.toJson()),
      );
      return true;
    } catch (e) {
      print('Error saving quiz: $e');
      return false;
    }
  }

  // Load a quiz from local storage
  static Future<QuizData?> loadQuiz(int transcriptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quizDataString = prefs.getString(AppConfig.quizKey(transcriptId));
      
      if (quizDataString != null) {
        return QuizData.fromJson(json.decode(quizDataString));
      }
    } catch (e) {
      print('Error loading quiz: $e');
    }
    return null;
  }

  // Delete a quiz from local storage
  static Future<bool> deleteQuiz(int transcriptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConfig.quizKey(transcriptId));
      return true;
    } catch (e) {
      print('Error deleting quiz: $e');
      return false;
    }
  }

  // Get all stored quiz transcript IDs
  static Future<Set<int>> getStoredQuizIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final quizKeys = keys.where((key) => key.startsWith('quiz_')).toList();
      
      return quizKeys
          .map((key) => int.parse(key.replaceFirst('quiz_', '')))
          .toSet();
    } catch (e) {
      print('Error checking stored quizzes: $e');
      return {};
    }
  }

  // Clear all quizzes
  static Future<bool> clearAllQuizzes() async {
    try {
      final quizIds = await getStoredQuizIds();
      final prefs = await SharedPreferences.getInstance();
      
      for (var id in quizIds) {
        await prefs.remove(AppConfig.quizKey(id));
      }
      return true;
    } catch (e) {
      print('Error clearing quizzes: $e');
      return false;
    }
  }
} 