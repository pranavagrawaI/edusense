import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'quiz_screen.dart';
import 'models/transcript.dart';

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
    final file = File(widget.audioPath);
    if (!await file.exists()) {
      _updateState("Error: Recording file not found");
      return;
    }

    try {
      var request = http.MultipartRequest(
          'POST',
          Uri.parse(
            'http://192.168.29.33:5000/transcribe',
          ), // Update your server IP
        )
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            widget.audioPath,
            filename: 'recording.aac',
          ),
        );

      print('Sending audio file: ${widget.audioPath}');
      print('File size: ${(await file.length()) / 1024} KB');

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        setState(() {
          _transcription =
              jsonData["transcription"] ?? "No transcription found";
          _transcriptId = jsonData["transcript_id"];
          _isLoading = false;
        });
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
              FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => QuizScreen(transcriptId: _transcriptId!),
                    ),
                  );
                },
                child: const Icon(Icons.quiz),
              ),
          ],
        ),
      ),
    );
  }
}

class TranscriptHistoryScreen extends StatefulWidget {
  const TranscriptHistoryScreen({super.key});

  @override
  State<TranscriptHistoryScreen> createState() => _TranscriptHistoryScreenState();
}

class _TranscriptHistoryScreenState extends State<TranscriptHistoryScreen> {
  List<Transcript> _transcripts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTranscripts();
  }

  Future<void> _loadTranscripts() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.29.33:5000/transcripts'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _transcripts = data.map((json) => Transcript.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load transcripts');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading transcripts: $e')),
      );
    }
  }

  Future<void> _deleteTranscript(int index) async {
    // TODO: Implement delete functionality with backend
    setState(() {
      _transcripts.removeAt(index);
    });
  }

  Future<void> _clearTranscripts() async {
    // TODO: Implement clear all functionality with backend
    setState(() {
      _transcripts.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text('Are you sure you want to delete all transcripts?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearTranscripts();
                        Navigator.pop(context);
                      },
                      child: const Text('Delete All'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transcripts.isEmpty
              ? const Center(child: Text('No transcripts yet'))
              : ListView.builder(
                  itemCount: _transcripts.length,
                  itemBuilder: (context, index) {
                    final transcript = _transcripts[index];
                    return Dismissible(
                      key: Key(transcript.id.toString()),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) => _deleteTranscript(index),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(
                            transcript.text.length > 100
                                ? '${transcript.text.substring(0, 100)}...'
                                : transcript.text,
                          ),
                          subtitle: Text(
                            'Recorded on ${DateFormat('MMM d, y HH:mm').format(transcript.timestamp)}',
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              transcript.hasQuiz ? Icons.quiz : Icons.add_circle,
                              color: transcript.hasQuiz ? Colors.green : Colors.blue,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      QuizScreen(transcriptId: transcript.id),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
