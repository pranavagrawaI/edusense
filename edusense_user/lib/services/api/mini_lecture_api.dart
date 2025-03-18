import '../../config/app_config.dart';
import 'api_client.dart';

class MiniLectureApi {
  // Generate a quiz for a transcript
  static Future<ApiResponse<Map<String, dynamic>>> generateMiniLecture(
      int transcriptId) async {
    return await ApiClient.post<Map<String, dynamic>>(
      AppConfig.generateMiniLectureEndpoint(transcriptId),
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }
} 