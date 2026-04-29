import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../models/mood.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _attitudeController;
  late TextEditingController _templateController;
  final Map<MoodType, TextEditingController> _moodControllers = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nameController = TextEditingController(text: settings.agentName);
    _attitudeController = TextEditingController(text: settings.agentAttitude);
    _templateController = TextEditingController(text: settings.systemContextTemplate);
    for (var type in MoodType.values) {
      _moodControllers[type] = TextEditingController(text: settings.moodPrompts[type]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _attitudeController.dispose();
    _templateController.dispose();
    for (var controller in _moodControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('Identity'),
          TextField(
            decoration: const InputDecoration(labelText: 'Agent Name'),
            controller: _nameController,
            onChanged: notifier.updateName,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Agent Attitude'),
            maxLines: 2,
            controller: _attitudeController,
            onChanged: notifier.updateAttitude,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'System Context Template',
              hintText: 'Use {name}, {attitude}, and {mood} as placeholders',
            ),
            maxLines: 3,
            controller: _templateController,
            onChanged: notifier.updateSystemContextTemplate,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Mood Management'),
          SwitchListTile(
            title: const Text('Autonomous Mood Switching'),
            subtitle: const Text('Allow the agent to change its mood based on context'),
            value: settings.autonomousMoodSwitching,
            onChanged: notifier.toggleAutonomous,
          ),
          const SizedBox(height: 16),
          const Text('Current Mood Override:'),
          Wrap(
            spacing: 8,
            children: MoodType.values.map((type) {
              return ChoiceChip(
                label: Text(type.label),
                selected: settings.currentMood == type,
                onSelected: (selected) {
                  if (selected) notifier.updateMood(type);
                },
                selectedColor: type.color.withOpacity(0.3),
                labelStyle: TextStyle(
                  color: settings.currentMood == type ? type.color : Colors.white,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Voice & Audio'),
          SwitchListTile(
            title: const Text('Use System TTS'),
            subtitle: const Text('Use native Android/iOS voice instead of high-fidelity Neural TTS'),
            value: settings.useSystemTts,
            onChanged: notifier.toggleSystemTts,
          ),
          SwitchListTile(
            title: const Text('Enable Web Search'),
            subtitle: const Text('Allow the AI to search the internet for answers'),
            value: settings.enableWebSearch,
            onChanged: notifier.toggleWebSearch,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Mood Prompts'),
          ...MoodType.values.map((type) {
            return ExpansionTile(
              leading: Icon(Icons.psychology, color: type.color),
              title: Text('${type.label} Prompt'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Enter custom prompt...'),
                    maxLines: 3,
                    controller: _moodControllers[type],
                    onChanged: (value) => notifier.updateMoodPrompt(type, value),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurpleAccent,
        ),
      ),
    );
  }
}
