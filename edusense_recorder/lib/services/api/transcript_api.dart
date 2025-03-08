import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../config/app_config.dart';
import '../../models/transcript.dart';
import 'api_client.dart';

class TranscriptApi {
  // Get all transcripts
  static Future<ApiResponse<List<Transcript>>> getTranscripts() async {
    return await ApiClient.get<List<Transcript>>(
      AppConfig.transcriptsEndpoint,
      fromJson: (data) => (data as List)
          .map((item) => Transcript.fromJson(item))
          .toList(),
    );
  }

  // Delete a transcript
  static Future<ApiResponse<bool>> deleteTranscript(int transcriptId) async {
    return await ApiClient.delete(
      AppConfig.deleteTranscriptEndpoint(transcriptId),
    );
  }

  // Delete all transcripts
  static Future<ApiResponse<bool>> deleteAllTranscripts() async {
    return await ApiClient.delete(AppConfig.transcriptsEndpoint);
  }

  // Upload and transcribe audio
  static Future<ApiResponse<Map<String, dynamic>>> transcribeAudio(
      String audioPath) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      return ApiResponse.error('Audio file not found', 404);
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.transcribeEndpoint),
      )..files.add(
          await http.MultipartFile.fromPath(
            'file',
            audioPath,
            filename: 'recording.aac',
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } else {
        return ApiResponse.error(
          'Server error: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Connection error: $e', 0);
    }
  }
} 