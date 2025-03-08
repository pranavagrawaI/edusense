import 'package:flutter/material.dart';
import '../../models/transcript.dart';
import '../../models/quiz.dart';
import '../../services/api/transcript_api.dart';
import '../../services/api/quiz_api.dart';
import '../../services/storage/quiz_storage.dart';
import '../widgets/transcript_card.dart';
import 'quiz_screen.dart';

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
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTranscripts(),
      _loadStoredQuizzes(),
    ]);
  }

  Future<void> _loadTranscripts() async {
    try {
      final response = await TranscriptApi.getTranscripts();
      
      setState(() {
        if (response.success && response.data != null) {
          _transcripts = response.data!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.error ?? "Unknown error"}')),
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading transcripts: $e')),
      );
    }
  }

  Future<void> _loadStoredQuizzes() async {
    final storedIds = await QuizStorage.getStoredQuizIds();
    setState(() {
      _transcriptsWithLocalQuizzes = storedIds;
    });
  }

  Future<void> _deleteTranscript(int index) async {
    final transcriptId = _transcripts[index].id;
    
    try {
      final response = await TranscriptApi.deleteTranscript(transcriptId);
      
      if (response.success) {
        // Delete local quiz if exists
        await QuizStorage.deleteQuiz(transcriptId);
        
        setState(() {
          _transcripts.removeAt(index);
          _transcriptsWithLocalQuizzes.remove(transcriptId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.error ?? "Unknown error"}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting transcript: $e')),
      );
    }
  }

  Future<void> _clearTranscripts() async {
    try {
      final response = await TranscriptApi.deleteAllTranscripts();
      
      if (response.success) {
        // Clear local quizzes
        await QuizStorage.clearAllQuizzes();
        
        setState(() {
          _transcripts.clear();
          _transcriptsWithLocalQuizzes.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.error ?? "Unknown error"}')),
        );
      }
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
      final response = await QuizApi.generateQuiz(transcriptId);
      
      if (response.success && response.data != null) {
        final quizData = response.data!['quiz_data'];
        final questions = (quizData['questions'] as List);
        
        // Convert JSON data to Quiz objects
        final quizList = questions
            .map((q) => Quiz.fromJson(q as Map<String, dynamic>))
            .toList();
            
        // Save quiz locally
        final saved = await QuizStorage.saveQuiz(transcriptId, quizList);
        
        if (saved) {
          setState(() {
            _transcriptsWithLocalQuizzes.add(transcriptId);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.error ?? 'Failed to generate quiz');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating quiz: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _generatingQuizzes.remove(transcriptId);
      });
    }
  }

  void _viewQuiz(int transcriptId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(transcriptId: transcriptId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _showClearConfirmationDialog(),
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
                    
                    return TranscriptCard(
                      transcript: transcript,
                      hasLocalQuiz: hasLocalQuiz,
                      isGeneratingQuiz: isGenerating,
                      onDelete: () => _deleteTranscript(index),
                      onViewQuiz: () => _viewQuiz(transcript.id),
                      onGenerateQuiz: () => _generateQuiz(transcript.id),
                    );
                  },
                ),
    );
  }
  
  void _showClearConfirmationDialog() {
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
  }
} 