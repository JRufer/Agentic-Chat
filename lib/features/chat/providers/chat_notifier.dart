import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/managed_runtime.dart';
import '../../../core/ai/prompt_assembler.dart';
import '../../../core/ai/mood_switcher.dart';
import '../../memory/services/memory_service.dart';
import '../../settings/providers/settings_provider.dart';
import 'chat_provider.dart';

class ChatNotifier extends StateNotifier<bool> {
  final Ref ref;
  final ManagedRuntime _runtime;
  final MemoryService _memory;
  late MoodSwitcher _moodSwitcher;

  ChatNotifier(this.ref, this._runtime, this._memory) : super(false) {
    _moodSwitcher = MoodSwitcher(ref); 
    
    // Listen for tokens from LLM
    _runtime.tokenStream.listen((token) {
      _handleToken(token);
    });
  }

  String _currentResponse = "";

  void _handleToken(String token) {
    _currentResponse += token;
    
    // Update the last message in history (if it's from the agent)
    final history = ref.read(chatHistoryProvider.notifier);
    // ... logic to update streaming message ...
    
    // Check for mood switch tool call
    if (_moodSwitcher.handleOutput(_currentResponse)) {
      // Mood was switched autonomously!
    }
  }

  Future<void> sendMessage(String text) async {
    state = true; // loading
    
    // 1. Add user message to history
    ref.read(chatHistoryProvider.notifier).addMessage(text, true);
    
    // 2. Retrieve context (RAG)
    final contextUnits = await _memory.retrieveContext(text);
    final contextText = contextUnits.map((e) => e.text).join("\n");
    
    // 3. Assemble prompt
    final settings = ref.read(settingsProvider);
    final systemPrompt = PromptAssembler.assemble(settings);
    final fullPrompt = "$systemPrompt\n\nRECALLED CONTEXT:\n$contextText\n\nUSER: $text\nASSISTANT:";
    
    // 4. Trigger inference
    _currentResponse = "";
    _runtime.generate(fullPrompt);
    
    // 5. Save user message to persistent memory
    await _memory.saveMessage(
      text: text, 
      isNote: false, 
      mood: settings.currentMood.name
    );
    
    state = false;
  }
}

final managedRuntimeProvider = Provider((ref) => ManagedRuntime());
// MemoryService and ChatNotifier providers would be defined here as well.
