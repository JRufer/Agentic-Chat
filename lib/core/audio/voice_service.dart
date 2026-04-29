import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:record/record.dart';

import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _isBargeinMonitoring = false;
  bool useSystemTts = false;

  // Called when the TTS queue fully drains (AI finished speaking).
  void Function()? onSpeakingComplete;
  // Called when the first phrase starts playing (AI began speaking).
  void Function()? onSpeakingStarted;

  bool get isSpeaking => _isSpeaking;
  
  StreamController<String>? _resultController;
  StreamSubscription? _recorderSubscription;
  sherpa.OnlineStream? _sttStream;

  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    
    // 1. Request Microphone Permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint("Microphone permission denied");
      return;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsPath = '${appDocDir.path}/models';

    // 2. Initialize Audio Session
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | 
                                     AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));

    try {
      // Initialize System TTS
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // 3. Check STT model files — these are required for voice input.
      final requiredSttFiles = [
        '$modelsPath/stt_encoder.onnx',
        '$modelsPath/stt_decoder.onnx',
        '$modelsPath/stt_joiner.onnx',
        '$modelsPath/stt_tokens.txt',
      ];

      for (final path in requiredSttFiles) {
        if (!await File(path).exists()) {
           debugPrint("VoiceService: Missing required STT file: $path");
           return;
        }
      }

      // Check TTS model files separately — missing files fall back to system TTS.
      final ttsFiles = [
        '$modelsPath/tts_vits_model.onnx',
        '$modelsPath/tts_vits_tokens.txt',
        '$modelsPath/tts_vits_lexicon.txt',
      ];
      final ttsFilesPresent = (await Future.wait(
        ttsFiles.map((p) => File(p).exists()),
      )).every((exists) => exists);
      if (!ttsFilesPresent) {
        debugPrint("VoiceService: Sherpa TTS files not found, using system TTS");
        useSystemTts = true;
      }

      // 4. Initialize Sherpa-ONNX global bindings
      sherpa.initBindings();

      debugPrint("VoiceService: Initializing with paths:");
      debugPrint("  STT Encoder: $modelsPath/stt_encoder.onnx");
      debugPrint("  TTS Model: $modelsPath/tts_vits_model.onnx");

      // 5. Initialize STT (Zipformer)
      final sttConfig = sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: '$modelsPath/stt_encoder.onnx',
            decoder: '$modelsPath/stt_decoder.onnx',
            joiner: '$modelsPath/stt_joiner.onnx',
          ),
          tokens: '$modelsPath/stt_tokens.txt',
          numThreads: 1,
          debug: false,
        ),
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 0.6,
      );
      _recognizer = sherpa.OnlineRecognizer(sttConfig);

      // 6. Initialize Sherpa TTS (VITS-LJS) only when model files are present.
      if (!useSystemTts) {
        final ttsConfig = sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: '$modelsPath/tts_vits_model.onnx',
              tokens: '$modelsPath/tts_vits_tokens.txt',
              lexicon: '$modelsPath/tts_vits_lexicon.txt',
            ),
            numThreads: 1,
            debug: true,
            provider: 'cpu',
          ),
        );
        _tts = sherpa.OfflineTts(ttsConfig);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint("VoiceService Init Error: $e");
    } finally {
      _isInitializing = false;
    }
  }

  Stream<String> startSTT() {
    if (!_isInitialized && !_isInitializing) {
       initialize();
    }
    
    if (!_isInitialized || _isListening) {
       return _resultController?.stream ?? const Stream.empty();
    }
    
    _isListening = true;
    _resultController = StreamController<String>.broadcast();

    // _sttStream creation (FFI) is deferred into _startRecording() so the
    // current frame (mic animation) can render before the synchronous FFI call.
    _startRecording();
    
    return _resultController!.stream;
  }

  Future<void> _startRecording() async {
    // Defer the synchronous FFI createStream() call so the animation frame
    // triggered by setState in _enterVoiceMode can render before we block.
    _sttStream = await Future(() => _recognizer?.createStream());

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
    );

    final stream = await _recorder.startStream(config);
    
    _recorderSubscription = stream.listen((data) {
      if (_recognizer == null || _sttStream == null) return;

      // Don't feed audio to the STT while the AI is speaking. Hardware AEC is
      // not reliable enough across all devices to fully cancel speaker output,
      // so we gate in software. The recorder keeps running for instant resume.
      if (_isSpeaking) return;

      // Convert Uint8List (PCM 16-bit) to Float32List
      final bytes = Uint8List.fromList(data);
      final int16List = bytes.buffer.asInt16List();
      final floatList = Float32List(int16List.length);
      for (int i = 0; i < int16List.length; i++) {
        floatList[i] = int16List[i] / 32768.0;
      }

      _sttStream!.acceptWaveform(samples: floatList, sampleRate: 16000);

      while (_recognizer!.isReady(_sttStream!)) {
        _recognizer!.decode(_sttStream!);
      }

      final result = _recognizer!.getResult(_sttStream!);

      // Only emit partial results when actively transcribing (not monitoring).
      if (!_isBargeinMonitoring && result.text.isNotEmpty) {
        debugPrint("STT Result: ${result.text}");
        _resultController!.add(result.text);
      }

      if (_recognizer!.isEndpoint(_sttStream!)) {
        if (_isBargeinMonitoring) {
          // A complete utterance endpoint while the AI is speaking = barge-in.
          // AEC suppresses echo so only real user speech reaches endpoint.
          if (result.text.trim().isNotEmpty) {
            debugPrint("Barge-in detected: ${result.text}");
            _isBargeinMonitoring = false;
            stopSpeaking(); // fire-and-forget
            _resultController?.add('[BARGE_IN]');
          }
        } else {
          debugPrint("STT Endpoint detected");
          _resultController!.add("[DONE]");
        }
        _recognizer!.reset(_sttStream!);
      }
    });
  }

  // Switch to barge-in monitor mode: keep the recorder running but watch for
  // user speech during TTS playback instead of transcribing to the text field.
  void startBargeinMonitor() {
    if (_isListening) _isBargeinMonitoring = true;
  }

  // Return to normal active listening (called when TTS finishes or on barge-in exit).
  void resumeActiveListening() {
    _isBargeinMonitoring = false;
  }

  Future<void> stopSTT() async {
    _isListening = false;
    _isBargeinMonitoring = false;
    await _recorder.stop();
    await _recorderSubscription?.cancel();
    _sttStream?.free();
    _sttStream = null;
    await _resultController?.close();
  }

  final List<String> _phraseQueue = [];
  bool _isProcessingQueue = false;

  Future<void> stopSpeaking() async {
    _phraseQueue.clear();
    await _player.stop();
    await _flutterTts.stop();
    _isSpeaking = false;
    _isProcessingQueue = false;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _phraseQueue.add(text);
    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    _isSpeaking = true;
    onSpeakingStarted?.call();

    if (useSystemTts) {
      while (_phraseQueue.isNotEmpty && _isProcessingQueue) {
        final text = _phraseQueue.removeAt(0);
        try {
          await _flutterTts.awaitSpeakCompletion(true);
          await _flutterTts.speak(text);
        } catch (e) {
          debugPrint("System TTS Error: $e");
        }
      }
      _isProcessingQueue = false;
      _isSpeaking = false;
      onSpeakingComplete?.call();
      return;
    }

    if (_tts == null) {
      _isProcessingQueue = false;
      _isSpeaking = false;
      return;
    }

    // Sherpa-ONNX path: pipeline synthesis with playback.
    // While phrase N is playing, phrase N+1 is being synthesised, hiding the
    // synthesis cost behind the playback duration.
    Future<Uint8List?>? pendingSynth;

    while (_isProcessingQueue) {
      if (pendingSynth == null) {
        if (_phraseQueue.isEmpty) break;
        final text = _phraseQueue.removeAt(0);
        pendingSynth = Future(() => _synthesizeToBytes(text));
      }

      final wavBytes = await pendingSynth;
      pendingSynth = null;

      // Kick off the next synthesis before awaiting playback so they overlap.
      if (_phraseQueue.isNotEmpty) {
        final nextText = _phraseQueue.removeAt(0);
        pendingSynth = Future(() => _synthesizeToBytes(nextText));
      }

      if (wavBytes != null && _isProcessingQueue) {
        await _playWavBytes(wavBytes);
      }
    }

    _isProcessingQueue = false;
    _isSpeaking = false;
    // Discard any audio the STT buffered during playback and wait briefly for
    // speaker echo to decay before re-enabling the microphone.
    if (_sttStream != null && _recognizer != null) {
      _recognizer!.reset(_sttStream!);
    }
    await Future.delayed(const Duration(milliseconds: 350));
    onSpeakingComplete?.call();
  }

  // Synthesises text to WAV bytes synchronously (FFI call). Runs on the Dart
  // event loop but yields to audio playback awaits between calls.
  Uint8List? _synthesizeToBytes(String text) {
    if (_tts == null) return null;
    try {
      final audio = _tts!.generate(text: text, sid: 0, speed: 1.1);
      final header = _createWavHeader(audio.samples.length * 2, audio.sampleRate);
      final pcm = ByteData(audio.samples.length * 2);
      for (int i = 0; i < audio.samples.length; i++) {
        final sample = (audio.samples[i] * 32767).clamp(-32768, 32767).toInt();
        pcm.setInt16(i * 2, sample, Endian.little);
      }
      return Uint8List.fromList(header + pcm.buffer.asUint8List());
    } catch (e) {
      debugPrint("TTS synthesis error: $e");
      return null;
    }
  }

  Future<void> _playWavBytes(Uint8List wavBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavBytes);
      await _player.setFilePath(tempFile.path);
      await _player.play();
      if (await tempFile.exists()) await tempFile.delete();
    } catch (e) {
      debugPrint("TTS playback error: $e");
    }
  }

  Uint8List _createWavHeader(int dataLength, int sampleRate) {
    final header = ByteData(44);
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataLength, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); //  
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // Mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataLength, Endian.little);
    return header.buffer.asUint8List();
  }

  void dispose() {
    _recognizer?.free();
    _tts?.free();
    _player.dispose();
  }
}
