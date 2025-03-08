class AppConfig {
  // Server configuration
  static const String serverIP = '192.168.29.33';
  static const int serverPort = 5000;
  static const String serverUrl = 'http://$serverIP:$serverPort';
  
  // API endpoints
  static const String transcribeEndpoint = '$serverUrl/transcribe';
  static const String transcriptsEndpoint = '$serverUrl/transcripts';
  static String generateQuizEndpoint(int transcriptId) => '$serverUrl/generate_quiz/$transcriptId';
  static String deleteTranscriptEndpoint(int transcriptId) => '$serverUrl/transcript/$transcriptId';
  
  // Local storage keys
  static String quizKey(int transcriptId) => 'quiz_$transcriptId';
} 