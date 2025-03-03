import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TranscriptionScreen extends StatefulWidget {
  final String audioPath;
  const TranscriptionScreen({super.key, required this.audioPath});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  String _transcription = "Transcribing...";
  bool _isLoading = true;
  bool _errorOccurred = false;

  @override
  void initState() {
    super.initState();
    _sendAudioForTranscription();
  }

  Future<void> _sendAudioForTranscription() async {
    final uri = Uri.parse("http://YOUR-SERVER-IP:5000/transcribe");

    try {
      // Show a loading indicator
      setState(() {
        _isLoading = true;
        _errorOccurred = false;
      });

      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', widget.audioPath));

      var response = await request.send();
      if (response.statusCode == 200) {
        // Read response
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);

        // Extract transcription text
        setState(() {
          _transcription = jsonData["transcription"] ?? "No text found.";
          _isLoading = false;
        });
      } else {
        // Error from server
        var responseData = await response.stream.bytesToString();
        print("Server Error: ${response.statusCode}, $responseData");

        setState(() {
          _transcription = "Error: Could not transcribe audio.";
          _isLoading = false;
          _errorOccurred = true;
        });
      }
    } catch (e) {
      // Network or other errors
      print("Exception: $e");
      setState(() {
        _transcription = "Error: Exception while transcribing.";
        _isLoading = false;
        _errorOccurred = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayText = _isLoading ? "Please wait..." : _transcription;
    return Scaffold(
      appBar: AppBar(title: const Text('Transcription')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _errorOccurred
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(displayText, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _sendAudioForTranscription,
                      child: const Text("Retry"),
                    ),
                  ],
                )
              : Text(displayText, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
