import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mood.dart';
import '../../../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/prompts_config.dart';

class SettingsState {
  final String agentName;
  final String agentAttitude;
  final MoodType currentMood;
  final bool autonomousMoodSwitching;
  final bool useSystemTts;
  final bool enableWebSearch;
  final Map<MoodType, String> moodPrompts;
  final String systemContextTemplate;

  SettingsState({
    required this.agentName,
    required this.agentAttitude,
    required this.currentMood,
    required this.autonomousMoodSwitching,
    required this.useSystemTts,
    required this.enableWebSearch,
    required this.moodPrompts,
    required this.systemContextTemplate,
  });

  SettingsState copyWith({
    String? agentName,
    String? agentAttitude,
    MoodType? currentMood,
    bool? autonomousMoodSwitching,
    bool? useSystemTts,
    bool? enableWebSearch,
    Map<MoodType, String>? moodPrompts,
    String? systemContextTemplate,
  }) {
    return SettingsState(
      agentName: agentName ?? this.agentName,
      agentAttitude: agentAttitude ?? this.agentAttitude,
      currentMood: currentMood ?? this.currentMood,
      autonomousMoodSwitching: autonomousMoodSwitching ?? this.autonomousMoodSwitching,
      useSystemTts: useSystemTts ?? this.useSystemTts,
      enableWebSearch: enableWebSearch ?? this.enableWebSearch,
      moodPrompts: moodPrompts ?? this.moodPrompts,
      systemContextTemplate: systemContextTemplate ?? this.systemContextTemplate,
    );
  }
}

class Settings extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    
    final prompts = <MoodType, String>{};
    for (var type in MoodType.values) {
      prompts[type] = prefs.getString('prompt_${type.name}') ?? Mood.defaultFor(type).prompt;
    }

    return SettingsState(
      agentName: prefs.getString('agentName') ?? PromptsConfig.defaultAgentName,
      agentAttitude: prefs.getString('agentAttitude') ?? PromptsConfig.defaultAgentAttitude,
      currentMood: MoodType.values.firstWhere(
        (e) => e.name == prefs.getString('currentMood'),
        orElse: () => MoodType.professional,
      ),
      autonomousMoodSwitching: prefs.getBool('autonomousMoodSwitching') ?? false,
      useSystemTts: prefs.getBool('useSystemTts') ?? false,
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

  void toggleSystemTts(bool value) {
    ref.read(sharedPreferencesProvider).setBool('useSystemTts', value);
    state = state.copyWith(useSystemTts: value);
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
