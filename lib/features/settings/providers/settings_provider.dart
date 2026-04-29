import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mood.dart';
import '../models/tts_engine.dart';
import '../../../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/prompts_config.dart';

class SettingsState {
  final String agentName;
  final String agentAttitude;
  final MoodType currentMood;
  final bool autonomousMoodSwitching;
  final TtsEngine ttsEngine;
  final bool enableWebSearch;
  final Map<MoodType, String> moodPrompts;
  final String systemContextTemplate;

  SettingsState({
    required this.agentName,
    required this.agentAttitude,
    required this.currentMood,
    required this.autonomousMoodSwitching,
    required this.ttsEngine,
    required this.enableWebSearch,
    required this.moodPrompts,
    required this.systemContextTemplate,
  });

  SettingsState copyWith({
    String? agentName,
    String? agentAttitude,
    MoodType? currentMood,
    bool? autonomousMoodSwitching,
    TtsEngine? ttsEngine,
    bool? enableWebSearch,
    Map<MoodType, String>? moodPrompts,
    String? systemContextTemplate,
  }) {
    return SettingsState(
      agentName: agentName ?? this.agentName,
      agentAttitude: agentAttitude ?? this.agentAttitude,
      currentMood: currentMood ?? this.currentMood,
      autonomousMoodSwitching: autonomousMoodSwitching ?? this.autonomousMoodSwitching,
      ttsEngine: ttsEngine ?? this.ttsEngine,
      enableWebSearch: enableWebSearch ?? this.enableWebSearch,
      moodPrompts: moodPrompts ?? this.moodPrompts,
      systemContextTemplate: systemContextTemplate ?? this.systemContextTemplate,
    );
  }

  // Convenience getter used by VoiceService and other callers.
  bool get useSystemTts => ttsEngine == TtsEngine.system;
}

class Settings extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    final prompts = <MoodType, String>{};
    for (var type in MoodType.values) {
      prompts[type] = prefs.getString('prompt_${type.name}') ?? Mood.defaultFor(type).prompt;
    }

    // Migrate from the old boolean useSystemTts key if present.
    final TtsEngine engine;
    final savedEngine = prefs.getString('ttsEngine');
    if (savedEngine != null) {
      engine = TtsEngine.values.firstWhere(
        (e) => e.name == savedEngine,
        orElse: () => TtsEngine.sherpaVits,
      );
    } else if (prefs.getBool('useSystemTts') == true) {
      engine = TtsEngine.system;
    } else {
      engine = TtsEngine.sherpaVits;
    }

    return SettingsState(
      agentName: prefs.getString('agentName') ?? PromptsConfig.defaultAgentName,
      agentAttitude: prefs.getString('agentAttitude') ?? PromptsConfig.defaultAgentAttitude,
      currentMood: MoodType.values.firstWhere(
        (e) => e.name == prefs.getString('currentMood'),
        orElse: () => MoodType.professional,
      ),
      autonomousMoodSwitching: prefs.getBool('autonomousMoodSwitching') ?? false,
      ttsEngine: engine,
      enableWebSearch: prefs.getBool('enableWebSearch') ?? false,
      moodPrompts: prompts,
      systemContextTemplate: PromptsConfig.defaultSystemContextTemplate,
    );
  }

  void updateName(String name) {
    ref.read(sharedPreferencesProvider).setString('agentName', name);
    state = state.copyWith(agentName: name);
  }

  void updateAttitude(String attitude) {
    ref.read(sharedPreferencesProvider).setString('agentAttitude', attitude);
    state = state.copyWith(agentAttitude: attitude);
  }

  void updateMood(MoodType mood) {
    ref.read(sharedPreferencesProvider).setString('currentMood', mood.name);
    state = state.copyWith(currentMood: mood);
  }

  void toggleAutonomous(bool value) {
    ref.read(sharedPreferencesProvider).setBool('autonomousMoodSwitching', value);
    state = state.copyWith(autonomousMoodSwitching: value);
  }

  void setTtsEngine(TtsEngine engine) {
    ref.read(sharedPreferencesProvider).setString('ttsEngine', engine.name);
    state = state.copyWith(ttsEngine: engine);
  }

  // Kept for backward compatibility with callers that still reference this name.
  void toggleSystemTts(bool value) {
    setTtsEngine(value ? TtsEngine.system : TtsEngine.sherpaVits);
  }

  void toggleWebSearch(bool value) {
    ref.read(sharedPreferencesProvider).setBool('enableWebSearch', value);
    state = state.copyWith(enableWebSearch: value);
  }

  void updateMoodPrompt(MoodType type, String prompt) {
    ref.read(sharedPreferencesProvider).setString('prompt_${type.name}', prompt);
    final newPrompts = Map<MoodType, String>.from(state.moodPrompts);
    newPrompts[type] = prompt;
    state = state.copyWith(moodPrompts: newPrompts);
  }

  void updateSystemContextTemplate(String template) {
    ref.read(sharedPreferencesProvider).setString('systemContextTemplate', template);
    state = state.copyWith(systemContextTemplate: template);
  }
}

final settingsProvider = NotifierProvider<Settings, SettingsState>(() {
  return Settings();
});
