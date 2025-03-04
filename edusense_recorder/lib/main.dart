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
      // Ensure directory exists
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      _filePath = '${tempDir.path}/lecture_${DateTime.now().millisecondsSinceEpoch}.wav';
      print('Starting recording to: $_filePath');

      // Verify writable directory
      final testFile = File('${tempDir.path}/test.txt');
      await testFile.writeAsString('test');
      await testFile.delete();
      
      await _recorder!.startRecorder(
        toFile: _filePath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
        audioSource: AudioSource.microphone,
      );
      setState(() => _isRecording = true);
    } catch (e) {
      _showSnackBar("Recording initialization failed: ${e.toString()}");
      print('Recording start error: $e');
      if (e is PathNotFoundException) {
        print('Path access error: ${e.message}');
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      // 1. Get current path before stopping
      final recordingPath = _filePath;
      
      // 2. Stop the recorder and wait for native completion
      await _recorder!.stopRecorder();
      
      // 3. Add extended delay for Android audio subsystem
      await Future.delayed(const Duration(seconds: 3));

      // 4. Verify file integrity
      final file = File(recordingPath);
      if (!await file.exists()) {
        _showSnackBar("File not created - check storage permissions");
        print('File missing at: $recordingPath');
        return;
      }

      // 5. Validate WAV header
      try {
        final header = await file.openRead(0, 4).first;
        if (String.fromCharCodes(header) != 'RIFF') {
          _showSnackBar("Invalid audio format");
          await file.delete();
          return;
        }
      } catch (e) {
        print('Header read error: $e');
      }

      // 6. Final validation
      final size = await file.length();
      print('Validated recording: $size bytes');
      
      if (size > 1024) {
        setState(() => _isRecording = false);
        _showSnackBar("Recording saved successfully");
      } else {
        await file.delete();
        _showSnackBar("Recording failed - invalid file");
      }
    } catch (e) {
      _showSnackBar("Recording finalization error: ${e.toString()}");
      print('Stop recording exception: $e');
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

