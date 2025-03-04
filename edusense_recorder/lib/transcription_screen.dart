import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class TranscriptionScreen extends StatefulWidget {
  final String audioPath;
  const TranscriptionScreen({super.key, required this.audioPath});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  String _transcription = "Transcribing...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sendAudioForTranscription();
  }

  Future<void> _sendAudioForTranscription() async {
    final file = File(widget.audioPath);
    if (!await file.exists()) {
      _updateState("Error: Recording file not found");
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.29.33:5000/transcribe'), // Update your server IP
      )
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          widget.audioPath,
          filename: 'recording.aac',
        ));

      print('Sending audio file: ${widget.audioPath}');
      print('File size: ${(await file.length()) / 1024} KB');

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        _updateState(jsonData["transcription"] ?? "No transcription found");
      } else {
        _updateState("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _updateState("Connection error: ${e.toString()}");
    }
  }

  void _updateState(String message) {
    if (!mounted) return;
    setState(() {
      _transcription = message;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transcription')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isLoading)
              const LinearProgressIndicator()
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _transcription,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            if (!_isLoading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('New Recording'),
              ),
          ],
        ),
      ),
    );
  }
}

