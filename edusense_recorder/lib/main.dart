import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'transcription_screen.dart';

void main() {
  runApp(const EduSenseRecorderApp());
}

class EduSenseRecorderApp extends StatelessWidget {
  const EduSenseRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: RecorderHome(),
    );
  }
}

class RecorderHome extends StatefulWidget {
  const RecorderHome({super.key});

  @override
  State<RecorderHome> createState() => _RecorderHomeState();
}

class _RecorderHomeState extends State<RecorderHome> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String _filePath = '';

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  /// Initialize the recorder and request microphone permission
  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();

    // Request microphone permission
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission is required to record audio")),
        );
      }
      return;
    }

    try {
      await _recorder?.openRecorder();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to initialize recorder: $e")),
        );
      }
    }
  }

  /// Start audio recording
  Future<void> _startRecording() async {
    if (_recorder == null) return;

    // Optionally store the file in a temp directory
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _filePath = '${directory.path}/lecture_$timestamp.wav';

    try {
      await _recorder?.startRecorder(
        toFile: _filePath,
        codec: Codec.pcm16WAV,
      );
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error starting recording: $e")),
        );
      }
    }
  }

  /// Stop audio recording
  Future<void> _stopRecording() async {
    if (_recorder == null) return;

    try {
      await _recorder?.stopRecorder();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error stopping recording: $e")),
        );
      }
    }
  }

  /// Navigate to transcription screen
  void _transcribeAudio() {
    if (_isRecording) {
      // We don't want to transcribe while still recording
      return;
    }

    if (_filePath.isEmpty) {
      // No file recorded yet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No audio file to transcribe.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TranscriptionScreen(audioPath: _filePath),
      ),
    );
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EduSense Recorder')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              iconSize: 64,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              onPressed: _isRecording ? _stopRecording : _startRecording,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? null : _transcribeAudio,
              child: const Text('Transcribe'),
            ),
          ],
        ),
      ),
    );
  }
}
