import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../models/mini_lecture.dart';

class MiniLectureStorage {
  // Save a mini-lecture to local storage
  static Future<bool> saveMiniLecture(int transcriptId, MiniLecture miniLectureData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert to JSON and store
      final jsonString = json.encode(miniLectureData.toJson());
      await prefs.setString(
        AppConfig.miniLectureKey(transcriptId),
        jsonString,
      );
      return true;
    } catch (e) {
      print('Error saving mini-lecture: $e');
      return false;
    }
  }

  // Load a mini-lecture from local storage
  static Future<MiniLecture?> loadMiniLecture(int transcriptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final miniLectureString = prefs.getString(AppConfig.miniLectureKey(transcriptId));
      
      if (miniLectureString != null) {
        return MiniLecture.fromJson(json.decode(miniLectureString));
      }
    } catch (e) {
      print('Error loading mini-lecture: $e');
    }
    return null;
  }

  // Delete a mini-lecture from local storage
  static Future<bool> deleteMiniLecture(int transcriptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConfig.miniLectureKey(transcriptId));
      return true;
    } catch (e) {
      print('Error deleting mini-lecture: $e');
      return false;
    }
  }

  // Get all stored mini-lecture transcript IDs
  static Future<Set<int>> getStoredMiniLectureIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // Filter keys that match the mini-lecture pattern, e.g. "mini_lecture_<ID>"
      final lectureKeys = allKeys.where((key) => key.startsWith('mini_lecture_')).toList();
      
      return lectureKeys
          .map((key) => int.parse(key.replaceFirst('mini_lecture_', '')))
          .toSet();
    } catch (e) {
      print('Error reading stored mini-lectures: $e');
      return {};
    }
  }

  // Clear all stored mini-lectures
  static Future<bool> clearAllMiniLectures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedIds = await getStoredMiniLectureIds();
      
      for (var id in storedIds) {
        await prefs.remove(AppConfig.miniLectureKey(id));
      }
      return true;
    } catch (e) {
      print('Error clearing mini-lectures: $e');
      return false;
    }
  }
}
