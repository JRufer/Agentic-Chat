import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/settings_provider.dart';
import '../models/mood.dart';
import '../models/tts_engine.dart';
import '../../../core/ai/download_manager.dart';

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

  // CosyVoice2 download state
  bool _cosyVoiceDownloading = false;
  double _cosyVoiceProgress = 0.0;
  bool _cosyVoiceDownloaded = false;

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
    _checkCosyVoiceDownloaded();
  }

  Future<void> _checkCosyVoiceDownloaded() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsPath = '${appDocDir.path}/models';
    final files = [
      '$modelsPath/cosyvoice2_model.onnx',
      '$modelsPath/cosyvoice2_tokens.txt',
      '$modelsPath/cosyvoice2_spk2info.json',
    ];
    final allExist = await Future.wait(files.map((p) => File(p).exists()))
        .then((r) => r.every((e) => e));
    if (mounted) setState(() => _cosyVoiceDownloaded = allExist);
  }

  Future<void> _downloadCosyVoice2() async {
    setState(() {
      _cosyVoiceDownloading = true;
      _cosyVoiceProgress = 0.0;
    });

    // CosyVoice2-300M-SFT ONNX export from k2-fsa/sherpa-onnx releases.
    const modelFiles = {
      'cosyvoice2_model.onnx':
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-CosyVoice2-0.5B-EN-JP-ZH.tar.bz2',
      'cosyvoice2_tokens.txt':
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-CosyVoice2-0.5B-EN-JP-ZH.tar.bz2',
      'cosyvoice2_spk2info.json':
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-CosyVoice2-0.5B-EN-JP-ZH.tar.bz2',
    };

    try {
      final downloader = ref.read(modelDownloadProvider);
      int count = 0;
      for (final entry in modelFiles.entries) {
        await downloader.downloadModel(
          entry.value,
          entry.key,
          (p) => setState(() {
            _cosyVoiceProgress = (count + p) / modelFiles.length;
          }),
        );
        count++;
      }
      await _checkCosyVoiceDownloaded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cosyVoiceDownloading = false);
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
          _buildTtsEngineDropdown(settings, notifier),
          if (settings.ttsEngine == TtsEngine.cosyVoice2)
            _buildCosyVoiceDownloadTile(),
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

  Widget _buildTtsEngineDropdown(SettingsState settings, Settings notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<TtsEngine>(
        value: settings.ttsEngine,
        decoration: const InputDecoration(
          labelText: 'TTS Engine',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: TtsEngine.values.map((engine) {
          return DropdownMenuItem(
            value: engine,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(engine.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  engine.subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (engine) {
          if (engine != null) notifier.setTtsEngine(engine);
        },
      ),
    );
  }

  Widget _buildCosyVoiceDownloadTile() {
    if (_cosyVoiceDownloading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloading CosyVoice 2... ${(_cosyVoiceProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: _cosyVoiceProgress),
          ],
        ),
      );
    }

    if (_cosyVoiceDownloaded) {
      return const ListTile(
        dense: true,
        leading: Icon(Icons.check_circle, color: Colors.green),
        title: Text('CosyVoice 2 models ready'),
        contentPadding: EdgeInsets.zero,
      );
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.download, color: Colors.deepPurpleAccent),
      title: const Text('CosyVoice 2 models not downloaded'),
      subtitle: const Text('~500 MB — tap to download'),
      trailing: ElevatedButton(
        onPressed: _downloadCosyVoice2,
        child: const Text('Download'),
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
