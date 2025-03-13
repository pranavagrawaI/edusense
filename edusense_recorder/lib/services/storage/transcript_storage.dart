import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TranscriptMetadata {
  final int transcriptId;
  final String title;

  TranscriptMetadata({
    required this.transcriptId,
    required this.title,
  });

  Map<String, dynamic> toJson() {
    return {
      'transcriptId': transcriptId,
      'title': title,
    };
  }

  factory TranscriptMetadata.fromJson(Map<String, dynamic> json) {
    return TranscriptMetadata(
      transcriptId: json['transcriptId'],
      title: json['title'],
    );
  }
}

class TranscriptStorage {
  static const String transcriptsKey = 'transcripts_metadata';

  // Save a new transcript metadata entry.
  static Future<bool> saveTranscriptMetadata(TranscriptMetadata metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Retrieve the current list; if none, start with an empty list.
      final jsonString = prefs.getString(transcriptsKey);
      List<dynamic> metadataList = jsonString != null ? json.decode(jsonString) : [];
      // Append the new metadata.
      metadataList.add(metadata.toJson());
      // Save back the updated list.
      await prefs.setString(transcriptsKey, json.encode(metadataList));
      return true;  
    } catch (e) {
      print('Error saving transcript metadata: $e');
      return false;
    }
  }

  // Load all stored transcript metadata.
  static Future<List<TranscriptMetadata>> loadTranscriptMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(transcriptsKey);
      if (jsonString != null) {
        List<dynamic> metadataList = json.decode(jsonString);
        return metadataList.map((e) => TranscriptMetadata.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error loading transcript metadata: $e');
    }
    return [];
  }

  // Delete metadata for a specific transcript.
  static Future<bool> deleteTranscriptMetadata(int transcriptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(transcriptsKey);
      if (jsonString != null) {
        List<dynamic> metadataList = json.decode(jsonString);
        metadataList.removeWhere((element) => element['transcriptId'] == transcriptId);
        await prefs.setString(transcriptsKey, json.encode(metadataList));
      }
      return true;
    } catch (e) {
      print('Error deleting transcript metadata: $e');
      return false;
    }
  }

  // Clear all transcript metadata.
  static Future<bool> clearAllTranscriptMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(transcriptsKey);
      return true;
    } catch (e) {
      print('Error clearing transcript metadata: $e');
      return false;
    }
  }
}
