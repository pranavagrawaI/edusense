import 'dart:convert';

import '../../config/app_config.dart';
import 'api_client.dart';

class QuizApi {
  // Generate a quiz for a transcript
  static Future<ApiResponse<Map<String, dynamic>>> generateQuiz(
      int transcriptId) async {
    return await ApiClient.post<Map<String, dynamic>>(
      AppConfig.generateQuizEndpoint(transcriptId),
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }
} 