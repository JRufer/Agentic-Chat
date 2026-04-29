import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';

class MemoryState extends Notifier<List<String>> {
  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getStringList('agent_memories') ?? [];
  }

  void saveMemory(String memory) {
    if (state.contains(memory)) return;
    final newState = [...state, memory];
    ref.read(sharedPreferencesProvider).setStringList('agent_memories', newState);
    state = newState;
  }

  void removeMemory(String memory) {
    final newState = state.where((m) => m != memory).toList();
    ref.read(sharedPreferencesProvider).setStringList('agent_memories', newState);
    state = newState;
  }

  void clearMemories() {
    ref.read(sharedPreferencesProvider).remove('agent_memories');
    state = [];
  }
}

final memoryProvider = NotifierProvider<MemoryState, List<String>>(() {
  return MemoryState();
});
