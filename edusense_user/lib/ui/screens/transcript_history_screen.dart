import 'package:flutter/material.dart';
import '../../models/transcript.dart';
import '../../services/api/transcript_api.dart';
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
    if (!mounted) return; // Check mounted before calling setState
    setState(() => _isLoading = true);

    // Load local transcripts
    final localMetadata = await TranscriptStorage.loadTranscriptMetadata();
    final localTranscripts =
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

    if (!mounted) return; // Check again before updating state
    setState(() {
      _transcripts = localTranscripts;
      _isLoading = false;
    });

    // Load transcripts from server
    try {
      final response = await TranscriptApi.getTranscripts();
      if (response.success && response.data != null) {
        if (!mounted) return;
        setState(() => _isLoading = true);
        if (!mounted) return;
        setState(() {
          _transcripts = response.data!;
        });
        // Save them locally...
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStoredMiniLectures() async {
    final storedIds = await MiniLectureStorage.getStoredMiniLectureIds();
    if (!mounted) return; // Check if the widget is still in the tree
    setState(() {
      _transcriptsWithLocalMiniLectures = storedIds;
    });
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
      appBar: AppBar(title: const Text('History')),
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
                    onViewMiniLecture: () => _viewMiniLecture(transcript.id),
                  );
                },
              ),
    );
  }
}
