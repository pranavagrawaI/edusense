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
    setState(() => _isLoading = true);

    // 1) Immediately load local transcripts so the UI shows something
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

    setState(() {
      _transcripts = localTranscripts;
      _isLoading = false;
    });

    // 2) Then try the server in the background
    try {
      final response = await TranscriptApi.getTranscripts();
      if (response.success && response.data != null) {
        setState(() => _isLoading = true);
        // Show server transcripts
        setState(() {
          _transcripts = response.data!;
        });
        // Save them locally
        for (var t in _transcripts) {
          final defaultTitle =
              t.text.length > 30 ? t.text.substring(0, 30) : t.text;
          await TranscriptStorage.saveTranscriptMetadata(
            TranscriptMetadata(transcriptId: t.id, title: defaultTitle),
          );
        }
      }
    } catch (e) {
      // If server fails, do nothing. We already have local data shown.
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStoredMiniLectures() async {
    final storedIds = await MiniLectureStorage.getStoredMiniLectureIds();
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
      appBar: AppBar(title: const Text('Lectures')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData, // calls your refresh method
                child:
                    _transcripts.isEmpty
                        ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.8,
                              child: const Center(
                                child: Text('No transcripts yet'),
                              ),
                            ),
                          ],
                        )
                        : ListView.builder(
                          itemCount: _transcripts.length,
                          itemBuilder: (context, index) {
                            final transcript = _transcripts[index];
                            final hasLocalMiniLecture =
                                _transcriptsWithLocalMiniLectures.contains(
                                  transcript.id,
                                );
                            final isGenerating =
                                _generatingMiniLectures[transcript.id] == true;

                            return TranscriptCard(
                              transcript: transcript,
                              hasLocalMiniLecture: hasLocalMiniLecture,
                              isGeneratingMiniLecture: isGenerating,
                              onViewMiniLecture:
                                  () => _viewMiniLecture(transcript.id),
                            );
                          },
                        ),
              ),
    );
  }
}
