import 'package:flutter/material.dart';
import 'dart:io';

import '../../services/api/transcript_api.dart';
import 'quiz_screen.dart';

class TranscriptionScreen extends StatefulWidget {
  final String audioPath;
  const TranscriptionScreen({super.key, required this.audioPath});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  String _transcription = "Transcribing...";
  bool _isLoading = true;
  int? _transcriptId;

  @override
  void initState() {
    super.initState();
    _sendAudioForTranscription();
  }

  Future<void> _sendAudioForTranscription() async {
    try {
      final response = await TranscriptApi.transcribeAudio(widget.audioPath);
      
      if (response.success && response.data != null) {
        setState(() {
          _transcription = response.data!["transcription"] ?? "No transcription found";
          _transcriptId = response.data!["transcript_id"];
          _isLoading = false;
        });
      } else {
        _updateState(response.error ?? "Error transcribing audio");
      }
    } catch (e) {
      _updateState("Error: ${e.toString()}");
    }
  }

  void _updateState(String message) {
    if (!mounted) return;
    setState(() {
      _transcription = message;
      _isLoading = false;
    });
  }

  void _saveAndExit() {
    Navigator.pop(context, _transcription);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: _saveAndExit,
                    child: const Text('Save & Exit'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            if (!_isLoading && _transcriptId != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizScreen(transcriptId: _transcriptId!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.quiz),
                  label: const Text('Generate Quiz'),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 