import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'quiz_screen.dart';
import 'models/transcript.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Set<int> _transcriptsWithLocalQuizzes = {};
  Map<int, bool> _generatingQuizzes = {};

  @override
  void initState() {
    super.initState();
    _loadTranscripts();
    _checkStoredQuizzes();
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

  Future<void> _checkStoredQuizzes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final quizKeys = keys.where((key) => key.startsWith('quiz_')).toList();
      
      setState(() {
        _transcriptsWithLocalQuizzes = quizKeys
            .map((key) => int.parse(key.replaceFirst('quiz_', '')))
            .toSet();
      });
    } catch (e) {
      print('Error checking stored quizzes: $e');
    }
  }

  Future<void> _deleteTranscript(int index) async {
    final transcriptId = _transcripts[index].id;
    
    try {
      // Delete from server
      await http.delete(
        Uri.parse('http://192.168.29.33:5000/transcript/$transcriptId'),
      );
      
      // Delete local quiz if exists
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('quiz_$transcriptId');
      
      setState(() {
        _transcripts.removeAt(index);
        _transcriptsWithLocalQuizzes.remove(transcriptId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting transcript: $e')),
      );
    }
  }

  Future<void> _clearTranscripts() async {
    try {
      // Clear from server
      await http.delete(Uri.parse('http://192.168.29.33:5000/transcripts'));
      
      // Clear local quizzes
      final prefs = await SharedPreferences.getInstance();
      for (var id in _transcriptsWithLocalQuizzes) {
        await prefs.remove('quiz_$id');
      }
      
      setState(() {
        _transcripts.clear();
        _transcriptsWithLocalQuizzes.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing transcripts: $e')),
      );
    }
  }

  Future<void> _generateQuiz(int transcriptId) async {
    setState(() {
      _generatingQuizzes[transcriptId] = true;
    });
    
    try {
      final response = await http.post(
        Uri.parse('http://192.168.29.33:5000/generate_quiz/$transcriptId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quizData = data['quiz_data'];
        
        // Save quiz locally
        final prefs = await SharedPreferences.getInstance();
        final quizDate = DateTime.now();
        
        await prefs.setString(
          'quiz_$transcriptId',
          json.encode({
            'transcript_id': transcriptId,
            'questions': quizData['questions'],
            'created_at': quizDate.toIso8601String(),
          }),
        );
        
        setState(() {
          _transcriptsWithLocalQuizzes.add(transcriptId);
          _generatingQuizzes.remove(transcriptId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to generate quiz');
      }
    } catch (e) {
      setState(() {
        _generatingQuizzes.remove(transcriptId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating quiz: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                    final hasLocalQuiz = _transcriptsWithLocalQuizzes.contains(transcript.id);
                    final isGenerating = _generatingQuizzes[transcript.id] == true;
                    
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
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: hasLocalQuiz || transcript.hasQuiz
                                ? Colors.blue.shade200
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Recorded on ${DateFormat('MMM d, y HH:mm').format(transcript.timestamp)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      if (hasLocalQuiz || transcript.hasQuiz)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.quiz,
                                                size: 16,
                                                color: hasLocalQuiz ? Colors.green : Colors.blue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Quiz Available',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: hasLocalQuiz ? Colors.green : Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    transcript.text.length > 150
                                        ? '${transcript.text.substring(0, 150)}...'
                                        : transcript.text,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isGenerating)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16, 
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Generating quiz...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (!isGenerating && !(hasLocalQuiz || transcript.hasQuiz))
                                  TextButton.icon(
                                    icon: const Icon(Icons.auto_awesome, color: Colors.orange),
                                    label: const Text(
                                      'Generate Quiz',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                    onPressed: () => _generateQuiz(transcript.id),
                                  ),
                                TextButton.icon(
                                  icon: Icon(
                                    hasLocalQuiz || transcript.hasQuiz
                                        ? Icons.quiz
                                        : Icons.add_circle,
                                    color: hasLocalQuiz
                                        ? Colors.green
                                        : transcript.hasQuiz
                                            ? Colors.blue
                                            : Colors.grey,
                                  ),
                                  label: Text(
                                    hasLocalQuiz || transcript.hasQuiz
                                        ? 'View Quiz'
                                        : 'Create Quiz',
                                    style: TextStyle(
                                      color: hasLocalQuiz
                                          ? Colors.green
                                          : transcript.hasQuiz
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
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
                                const SizedBox(width: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
