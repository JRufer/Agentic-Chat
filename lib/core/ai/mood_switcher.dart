import 'dart:convert';
import '../../features/settings/models/mood.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MoodSwitcher {
  final Ref ref;

  MoodSwitcher(this.ref);

  /// Parses the LLM output for a tool call to switch mood.
  /// Returns true if a mood switch was detected and handled.
  bool handleOutput(String output) {
    try {
      // Basic regex to find JSON tool call
      final regex = RegExp(r'\{.*"name":\s*"switch_mood".*\}', dotAll: true);
      final match = regex.firstMatch(output);
      
      if (match != null) {
        final jsonStr = match.group(0)!;
        final data = jsonDecode(jsonStr);
        final targetMoodName = data['parameters']['target_mood'] as String;
        
        final targetMood = MoodType.values.firstWhere(
          (e) => e.name == targetMoodName,
          orElse: () => MoodType.professional,
        );

        // Update the global state
        ref.read(settingsProvider.notifier).updateMood(targetMood);
        return true;
      }
    } catch (e) {
      // Robustness: Handle malformed JSON or hallucinations
      print("Mood switch error: $e");
    }
    return false;
  }
}
