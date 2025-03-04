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
    final uri = Uri.parse(const String.fromEnvironment(
      'TRANSCRIPTION_URL', defaultValue: "http://192.168.29.33:5000/transcribe"));

    final file = File(widget.audioPath);
    if (!await file.exists() || await file.length() < 1024) {
      _setErrorState("Invalid or missing recording file");
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'file', widget.audioPath,
          filename: widget.audioPath.split(Platform.pathSeparator).last,
        ));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        setState(() {
          _transcription = jsonData["transcription"] ?? "No text found.";
          _isLoading = false;
        });
      } else {
        _setErrorState("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      _setErrorState("Exception: $e");
    }
  }

  void _setErrorState(String message) {
    print(message);
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
        child: Center(
          child: _isLoading 
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  child: Text(
                    _transcription,
                    style: const TextStyle(fontSize: 18, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }
}
