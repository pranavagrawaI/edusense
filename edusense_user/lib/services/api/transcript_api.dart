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
} 