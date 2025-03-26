import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async';

import 'ui/screens/transcription_screen.dart';
import 'ui/screens/transcript_history_screen.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('startRecording').listen((event) {
      // Handle start recording
      print('Background recording started');
    });

    service.on('stopRecording').listen((event) {
      // Handle stop recording
      print('Background recording stopped');
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background service first
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: 'EduSense Recording',
      initialNotificationContent: 'Recording in progress',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await AndroidAlarmManager.initialize();

  runApp(const EduSenseRecorderApp());
}

class EduSenseRecorderApp extends StatelessWidget {
  const EduSenseRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduSense Recorder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const RecorderHome(),
    );
  }
}

class RecorderHome extends StatefulWidget {
  const RecorderHome({super.key});

  @override
  State<RecorderHome> createState() => _RecorderHomeState();
}

class _RecorderHomeState extends State<RecorderHome>
    with WidgetsBindingObserver {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String _filePath = '';
  final FlutterBackgroundService _backgroundService =
      FlutterBackgroundService();
  Timer? _timer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRecorder();
    _cleanupOldRecordings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder?.closeRecorder();
    _cleanupAudioFile();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isRecording) {
      _startBackgroundRecording();
    } else if (state == AppLifecycleState.resumed) {
      _stopBackgroundRecording();
    }
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
      _filePath =
          '${tempDir.path}/lecture_${DateTime.now().millisecondsSinceEpoch}.aac';
      print('Starting recording to: $_filePath');

      await _recorder!.startRecorder(
        toFile: _filePath,
        codec: Codec.aacADTS,
        sampleRate: 16000,
        numChannels: 1,
        audioSource: AudioSource.microphone,
      );
      setState(() => _isRecording = true);
      _startTimer();
    } catch (e) {
      _showSnackBar("Recording initialization failed: ${e.toString()}");
      print('Recording start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final recordingPath = _filePath;
      await _recorder!.stopRecorder();
      await _stopBackgroundRecording();

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
      _stopTimer();
    } catch (e) {
      _showSnackBar("Finalization error: ${e.toString()}");
    }
  }

  Future<void> _startBackgroundRecording() async {
    if (!_isRecording) return;

    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );

    await _backgroundService.startService();
    _backgroundService.invoke('startRecording', {'filePath': _filePath});
  }

  Future<void> _stopBackgroundRecording() async {
    if (!_isRecording) return;
    _backgroundService.invoke('stopRecording');
    _backgroundService.invoke('stopService');
  }

  Future<void> _cleanupAudioFile() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        await file.delete();
        print('Cleaned up audio file: $_filePath');
      }
    } catch (e) {
      print('Error cleaning up audio file: $e');
    }
  }

  void _transcribeAudio() async {
    if (_isRecording) return;
    final file = File(_filePath);
    if (!file.existsSync() || file.lengthSync() < 4096) {
      _showSnackBar("Please record audio first (min 2 seconds)");
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TranscriptionScreen(audioPath: _filePath),
        ),
      );

      if (result != null && result is String) {
        // No need to save locally anymore, server handles it
        // Clean up the audio file after successful transcription
        await _cleanupAudioFile();
      }
    } catch (e) {
      _showSnackBar("Error during transcription: ${e.toString()}");
    }
  }

  Future<void> _cleanupOldRecordings() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (var file in files) {
        if (file is File && file.path.contains('lecture_')) {
          // Check if file is older than 24 hours
          final fileAge = DateTime.now().difference(file.lastModifiedSync());
          if (fileAge.inHours > 24) {
            await file.delete();
            print('Deleted old recording: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up old recordings: $e');
    }
  }

  void _startTimer() {
    _recordingDuration = Duration.zero;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration += Duration(seconds: 1);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String get _formattedDuration {
    final minutes = _recordingDuration.inMinutes;
    final seconds = _recordingDuration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EduSense Recorder')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _isRecording ? _formattedDuration : '00:00',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TranscriptHistoryScreen(),
                  ),
                );
              },
              child: const Text('View History'),
            ),
          ],
        ),
      ),
    );
  }
}
