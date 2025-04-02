import 'package:flutter/material.dart';
import '../../models/mini_lecture.dart';
import '../../services/storage/mini_lecture_storage.dart';
import '../../services/api/mini_lecture_api.dart';

class MiniLectureScreen extends StatefulWidget {
  final int transcriptId;

  const MiniLectureScreen({super.key, required this.transcriptId});

  @override
  _MiniLectureScreenState createState() => _MiniLectureScreenState();
}

class _MiniLectureScreenState extends State<MiniLectureScreen> {
  MiniLecture? miniLecture;
  bool isLoading = false;

  // Track the user’s selected answer for each MCQ: [questionIndex -> 'A'/'B'/'C'/'D']
  Map<int, String> selectedAnswers = {};

  // Track whether the user has clicked "Check Answer" for each MCQ
  Map<int, bool> showAnswerForQuestion = {};

  @override
  void initState() {
    super.initState();
    _loadOrGenerateMiniLecture();
  }

  Future<void> _loadOrGenerateMiniLecture() async {
    setState(() {
      isLoading = true;
    });

    // Try to load the mini-lecture from local storage.
    final storedMiniLecture =
        await MiniLectureStorage.loadMiniLecture(widget.transcriptId);
    if (storedMiniLecture != null) {
      setState(() {
        miniLecture = storedMiniLecture;
        isLoading = false;
      });
      return;
    }

    // If not found locally, fetch from the server using the GET endpoint.
    final response = await MiniLectureApi.getMiniLecture(widget.transcriptId);
    if (response.success && response.data != null) {
      final miniLectureData = response.data as Map<String, dynamic>;
      final fetchedLecture = MiniLecture.fromJson(miniLectureData);

      // Save the fetched mini-lecture locally.
      await MiniLectureStorage.saveMiniLecture(widget.transcriptId, fetchedLecture);
      setState(() {
        miniLecture = fetchedLecture;
        isLoading = false;
      });
    } else {
      // Optionally, show an error message if fetching fails.
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load mini lecture.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mini Lecture')),
      body: RefreshIndicator(
        onRefresh: _loadOrGenerateMiniLecture,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : miniLecture == null
                ? ListView(
                    children: const [
                      SizedBox(
                        height: 200,
                        child: Center(child: Text('No mini-lecture found. Pull to refresh.')),
                      )
                    ],
                  )
                : _buildMiniLectureContent(),
      ),
    );
  }

  Widget _buildMiniLectureContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAbstractSection(),
          const SizedBox(height: 24),
          _buildKeyTopicsSection(),
          const SizedBox(height: 24),
          _buildMcqSection(),
        ],
      ),
    );
  }

  // 1) Abstract (Lecture Summary)
  Widget _buildAbstractSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Abstract',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(miniLecture!.abstract, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  // 2) Key Topics Section
  Widget _buildKeyTopicsSection() {
    if (miniLecture!.keyTopics.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Topics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...miniLecture!.keyTopics.map((topic) => _buildTopicCard(topic)),
      ],
    );
  }

  Widget _buildTopicCard(KeyTopic topic) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              topic.topic,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(topic.definition, style: const TextStyle(fontSize: 14)),
            if (topic.insights.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Insights:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ...topic.insights.map((insight) => Text('- $insight')),
            ],
          ],
        ),
      ),
    );
  }

  // 3) MCQs Section
  Widget _buildMcqSection() {
    if (miniLecture!.mcqs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multiple Choice Questions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          miniLecture!.mcqs.length,
          (index) => _buildQuizCard(miniLecture!.mcqs[index], index),
        ),
      ],
    );
  }

  Widget _buildQuizCard(MCQ quiz, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${index + 1}:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(quiz.question),
            const SizedBox(height: 16),
            // Radio buttons for each option
            ...quiz.options.entries.map(
              (option) => RadioListTile<String>(
                title: Text(option.value),
                value: option.key,
                groupValue: selectedAnswers[index],
                onChanged: (value) {
                  setState(() {
                    selectedAnswers[index] = value!;
                  });
                },
              ),
            ),
            // "Check Answer" button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: selectedAnswers[index] == null
                      ? null
                      : () {
                          setState(() {
                            showAnswerForQuestion[index] = true;
                          });
                        },
                  child: const Text('Check Answer'),
                ),
              ],
            ),
            // If "Check Answer" was pressed, show the feedback.
            if (showAnswerForQuestion[index] == true)
              _buildResultsFeedback(quiz, index),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsFeedback(MCQ quiz, int index) {
    final userAnswer = selectedAnswers[index];
    final isCorrect = userAnswer == quiz.correctAnswer;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect
                ? '✅ "$userAnswer" is Correct!'
                : '❌ "$userAnswer" is Incorrect',
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explanation: ${quiz.explanation}',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
