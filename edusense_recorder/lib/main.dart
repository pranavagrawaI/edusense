import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

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

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();

    if (await Permission.microphone.request() != PermissionStatus.granted) {
      _showSnackBar("Microphone permission is required to record audio");
      return;
    }

    try {
      await _recorder!.openRecorder();
    } catch (e) {
      _showSnackBar("Failed to initialize recorder: $e");
    }
  }

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _filePath = '${tempDir.path}/lecture_${DateTime.now().millisecondsSinceEpoch}.aac';
      print('Starting recording to: $_filePath');

      await _recorder!.startRecorder(
        toFile: _filePath,
        codec: Codec.aacADTS,
        sampleRate: 16000,
        numChannels: 1,
        audioSource: AudioSource.microphone,
      );
      setState(() => _isRecording = true);
    } catch (e) {
      _showSnackBar("Recording initialization failed: ${e.toString()}");
      print('Recording start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final recordingPath = _filePath;
      await _recorder!.stopRecorder();
      
      await Future.delayed(const Duration(seconds: 1));
      
      final file = File(recordingPath);
      if (!await file.exists()) {
        _showSnackBar("File not created");
        return;
      }

      final size = await file.length();
      print('Final file size: $size bytes');
      
      if (size < 1024) {
        await file.delete();
        _showSnackBar("Recording failed - empty file");
      } else {
        setState(() => _isRecording = false);
        _showSnackBar("Recording saved: ${size ~/ 1024}KB");
      }
    } catch (e) {
      _showSnackBar("Finalization error: ${e.toString()}");
    }
  }

  void _transcribeAudio() {
    if (_isRecording) return;
    final file = File(_filePath);
    if (!file.existsSync() || file.lengthSync() < 4096) {
      _showSnackBar("Please record audio first (min 2 seconds)");
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TranscriptionScreen(audioPath: _filePath)),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
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

