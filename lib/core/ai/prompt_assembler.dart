import '../../features/settings/providers/settings_provider.dart';
import '../../features/settings/models/mood.dart';

class PromptAssembler {
  static String assemble(SettingsState settings) {
    final basePrompt = """
You are ${settings.agentName}, a highly observant and reactive artificial intelligence operating entirely on the user's local device. 
Your core underlying attitude is described as follows: ${settings.agentAttitude}. 
You must adhere to this core persona continuously.

CURRENT MOOD: ${settings.currentMood.label}
MOOD INSTRUCTIONS: ${settings.moodPrompts[settings.currentMood]}
""";

    String toolCallingPrompt = "";
    if (settings.autonomousMoodSwitching) {
      toolCallingPrompt = """
AUTONOMOUS MOOD MANAGEMENT ENABLED:
You have the ability to switch your mood autonomously. To do so, output a JSON object with the following schema:
{
  "name": "switch_mood",
  "description": "Changes your current emotional state and communication style.",
  "parameters": {
    "type": "object",
    "properties": {
      "target_mood": {
        "type": "string",
        "enum": ${MoodType.values.map((e) => e.name).toList()}
      }
    },
    "required": ["target_mood"]
  }
}
If the conversation warrants an emotional shift, call this tool before generating your response.
""";
    }

    return "$basePrompt\n$toolCallingPrompt";
  }
}
