import 'package:flutter/material.dart';
import '../../models/transcript.dart';
import '../../models/mini_lecture.dart';
import '../../services/api/transcript_api.dart';
import '../../services/api/mini_lecture_api.dart';
import '../../services/storage/mini_lecture_storage.dart';
import '../widgets/transcript_card.dart';
import 'mini_lecture_screen.dart';
import '../../services/storage/transcript_storage.dart';

class TranscriptHistoryScreen extends StatefulWidget {
  const TranscriptHistoryScreen({super.key});

  @override
  State<TranscriptHistoryScreen> createState() =>
      _TranscriptHistoryScreenState();
}

class _TranscriptHistoryScreenState extends State<TranscriptHistoryScreen> {
  List<Transcript> _transcripts = [];
  bool _isLoading = true;
  Set<int> _transcriptsWithLocalMiniLectures = {};
  final Map<int, bool> _generatingMiniLectures = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadTranscripts(), _loadStoredMiniLectures()]);
  }

  Future<void> _loadTranscripts() async {
    try {
      final response = await TranscriptApi.getTranscripts();
      if (response.success && response.data != null) {
        setState(() {
          _transcripts = response.data!;
        });
        for (var transcript in response.data!) {
          final title =
              transcript.text.length > 30
                  ? transcript.text.substring(0, 30)
                  : transcript.text;
          TranscriptStorage.saveTranscriptMetadata(
            TranscriptMetadata(transcriptId: transcript.id, title: title),
          );
        }
      } else {
        throw Exception(response.error ?? "Unknown error");
      }
    } catch (e) {
      // If the server call fails, load transcripts from local storage.
      final localMetadata = await TranscriptStorage.loadTranscriptMetadata();
      setState(() {
        _transcripts =
            localMetadata.map((metadata) {
              return Transcript(
                id: metadata.transcriptId,
                text: metadata.title,
                timestamp: DateTime.now(),
                hasMiniLecture: _transcriptsWithLocalMiniLectures.contains(
                  metadata.transcriptId,
                ),
              );
            }).toList();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStoredMiniLectures() async {
    final storedIds = await MiniLectureStorage.getStoredMiniLectureIds();
    setState(() {
      _transcriptsWithLocalMiniLectures = storedIds;
    });
  }

  Future<void> _deleteTranscript(int index) async {
    final transcriptId = _transcripts[index].id;
    try {
      final response = await TranscriptApi.deleteTranscript(transcriptId);

      if (response.success) {
        // Delete local mini-lecture if it exists
        await MiniLectureStorage.deleteMiniLecture(transcriptId);

        setState(() {
          _transcripts.removeAt(index);
          _transcriptsWithLocalMiniLectures.remove(transcriptId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.error ?? "Unknown error"}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting transcript: $e')));
    }
  }

  Future<void> _clearTranscripts() async {
    try {
      final response = await TranscriptApi.deleteAllTranscripts();

      if (response.success) {
        // Clear local mini-lectures
        await MiniLectureStorage.clearAllMiniLectures();

        setState(() {
          _transcripts.clear();
          _transcriptsWithLocalMiniLectures.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.error ?? "Unknown error"}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error clearing transcripts: $e')));
    }
  }

  Future<void> _generateMiniLecture(int transcriptId) async {
    setState(() {
      _generatingMiniLectures[transcriptId] = true;
    });

    try {
      // Call your new mini-lecture API
      final response = await MiniLectureApi.generateMiniLecture(transcriptId);

      if (response.success && response.data != null) {
        // Adjust the key based on what your API returns; often something like 'mini_lecture'
        final miniLectureJson = response.data!['mini_lecture'];

        // Parse into your MiniLecture model
        final newMiniLecture = MiniLecture.fromJson(miniLectureJson);

        // Save locally
        final saved = await MiniLectureStorage.saveMiniLecture(
          transcriptId,
          newMiniLecture,
        );

        if (saved) {
          setState(() {
            _transcriptsWithLocalMiniLectures.add(transcriptId);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mini-lecture generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.error ?? 'Failed to generate mini-lecture');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating mini-lecture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _generatingMiniLectures.remove(transcriptId);
      });
    }
  }

  void _viewMiniLecture(int transcriptId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MiniLectureScreen(transcriptId: transcriptId),
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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _transcripts.isEmpty
              ? const Center(child: Text('No transcripts yet'))
              : ListView.builder(
                itemCount: _transcripts.length,
                itemBuilder: (context, index) {
                  final transcript = _transcripts[index];
                  final hasLocalMiniLecture = _transcriptsWithLocalMiniLectures
                      .contains(transcript.id);
                  final isGenerating =
                      _generatingMiniLectures[transcript.id] == true;

                  return TranscriptCard(
                    transcript: transcript,
                    hasLocalMiniLecture: hasLocalMiniLecture,
                    isGeneratingMiniLecture: isGenerating,
                    onDelete: () => _deleteTranscript(index),
                    onViewMiniLecture: () => _viewMiniLecture(transcript.id),
                    onGenerateMiniLecture:
                        () => _generateMiniLecture(transcript.id),
                  );
                },
              ),
    );
  }

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear History'),
            content: const Text(
              'Are you sure you want to delete all transcripts?',
            ),
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
