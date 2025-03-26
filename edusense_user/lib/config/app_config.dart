class AppConfig {
  // Server configuration
  static const String serverIP = '172.29.51.86';
  static const int serverPort = 5000;
  static const String serverUrl = 'http://$serverIP:$serverPort';
  
  // API endpoints
  static const String transcribeEndpoint = '$serverUrl/transcribe';
  static const String transcriptsEndpoint = '$serverUrl/transcripts';
  static String generateMiniLectureEndpoint(int transcriptId) => '$serverUrl/generate_mini_lecture/$transcriptId';
  static String deleteTranscriptEndpoint(int transcriptId) => '$serverUrl/transcript/$transcriptId';
  
  // Local storage keys
  static String miniLectureKey(int transcriptId) => 'mini_lecture_$transcriptId';
} 