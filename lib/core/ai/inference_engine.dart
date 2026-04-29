import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:path_provider/path_provider.dart';

abstract class InferenceEngine {
  Future<void> initialize();
  Stream<String> generate(String prompt);
  Future<void> resetConversation(String systemInstruction);
  Future<void> stop();
  Future<void> dispose();
}

class GemmaInferenceEngine implements InferenceEngine {
  LiteLmEngine? _engine;
  LiteLmConversation? _conversation;

  @override
  Future<void> initialize([String? appDocPath]) async {
    final path = appDocPath ?? (await getApplicationDocumentsDirectory()).path;
    final modelPath = '$path/models/gemma_v4_final.litertlm';
    
    if (await File(modelPath).exists()) {
      try {
        debugPrint("Initializing LiteLmEngine with GPU...");
        _engine = await LiteLmEngine.create(
          LiteLmEngineConfig(
            modelPath: modelPath,
            backend: LiteLmBackend.gpu,
          ),
        );
      } catch (e) {
        debugPrint("GPU Initialization failed, falling back to CPU: $e");
        _engine = await LiteLmEngine.create(
          LiteLmEngineConfig(
            modelPath: modelPath,
            backend: LiteLmBackend.cpu,
          ),
        );
      }
      _conversation = await _engine!.createConversation(
        const LiteLmConversationConfig(systemInstruction: "You are a helpful AI assistant."),
      );
    } else {
      throw Exception("Model file not found at $modelPath");
    }
  }

  @override
  Stream<String> generate(String prompt) {
    if (_conversation == null) {
      return Stream.value("Error: Model not initialized.");
    }
    return _conversation!.sendMessageStream(prompt).map((msg) => msg.text);
  }

  @override
  Future<void> resetConversation(String systemInstruction) async {
    if (_engine == null) return;
    await _conversation?.dispose();
    _conversation = await _engine!.createConversation(
      LiteLmConversationConfig(systemInstruction: systemInstruction),
    );
  }

  @override
  Future<void> stop() async {
    // Current flutter_litert_lm version might not support interruption yet
  }

  @override
  Future<void> dispose() async {
    await _conversation?.dispose();
    await _engine?.dispose();
  }
}
