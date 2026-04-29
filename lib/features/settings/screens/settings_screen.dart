import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/settings_provider.dart';
import '../models/mood.dart';
import '../models/tts_engine.dart';
import '../../../core/ai/download_manager.dart';

// Model files required for each downloadable engine.
const _kokoroFiles = {
  'kokoro_model.onnx':
      'https://huggingface.co/csukuangfj/sherpa-onnx-kokoro-en-v0_19/resolve/main/model.onnx',
  'kokoro_voices.bin':
      'https://huggingface.co/csukuangfj/sherpa-onnx-kokoro-en-v0_19/resolve/main/voices.bin',
  'kokoro_tokens.txt':
      'https://huggingface.co/csukuangfj/sherpa-onnx-kokoro-en-v0_19/resolve/main/tokens.txt',
};

const _matchaFiles = {
  'matcha_acoustic.onnx':
      'https://huggingface.co/csukuangfj/matcha-icefall-en_US-ljspeech/resolve/main/model-steps-3.onnx',
  'matcha_vocoder.onnx':
      'https://huggingface.co/csukuangfj/matcha-icefall-en_US-ljspeech/resolve/main/hifigan_v2.onnx',
  'matcha_lexicon.txt':
      'https://huggingface.co/csukuangfj/matcha-icefall-en_US-ljspeech/resolve/main/lexicon.txt',
  'matcha_tokens.txt':
      'https://huggingface.co/csukuangfj/matcha-icefall-en_US-ljspeech/resolve/main/tokens.txt',
};

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

  bool _kokoroDownloading = false;
  double _kokoroProgress = 0.0;
  bool _kokoroDownloaded = false;

  bool _matchaDownloading = false;
  double _matchaProgress = 0.0;
  bool _matchaDownloaded = false;

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
    _checkDownloadedModels();
  }

  Future<void> _checkDownloadedModels() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsPath = '${appDocDir.path}/models';

    final kokoroReady = await Future.wait(
      _kokoroFiles.keys.map((f) => File('$modelsPath/$f').exists()),
    ).then((r) => r.every((e) => e));

    final matchaReady = await Future.wait(
      _matchaFiles.keys.map((f) => File('$modelsPath/$f').exists()),
    ).then((r) => r.every((e) => e));

    if (mounted) {
      setState(() {
        _kokoroDownloaded = kokoroReady;
        _matchaDownloaded = matchaReady;
      });
    }
  }

  Future<void> _downloadEngine(
    Map<String, String> fileMap,
    void Function(bool downloading, double progress) onUpdate,
    void Function(bool downloaded) onDone,
  ) async {
    onUpdate(true, 0.0);
    try {
      final downloader = ref.read(modelDownloadProvider);
      int count = 0;
      for (final entry in fileMap.entries) {
        await downloader.downloadModel(
          entry.value,
          entry.key,
          (p) => onUpdate(true, (count + p) / fileMap.length),
        );
        count++;
      }
      await _checkDownloadedModels();
      onDone(true);
    } catch (e) {
      onDone(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _downloadKokoro() => _downloadEngine(
        _kokoroFiles,
        (downloading, progress) => setState(() {
          _kokoroDownloading = downloading;
          _kokoroProgress = progress;
        }),
        (downloaded) => setState(() {
          _kokoroDownloading = false;
          _kokoroDownloaded = downloaded;
        }),
      );

  void _downloadMatcha() => _downloadEngine(
        _matchaFiles,
        (downloading, progress) => setState(() {
          _matchaDownloading = downloading;
          _matchaProgress = progress;
        }),
        (downloaded) => setState(() {
          _matchaDownloading = false;
          _matchaDownloaded = downloaded;
        }),
      );

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
          if (settings.ttsEngine == TtsEngine.kokoro)
            _buildDownloadTile(
              label: 'Kokoro TTS models',
              downloaded: _kokoroDownloaded,
              downloading: _kokoroDownloading,
              progress: _kokoroProgress,
              onDownload: _downloadKokoro,
            ),
          if (settings.ttsEngine == TtsEngine.matcha)
            _buildDownloadTile(
              label: 'Matcha-TTS models',
              downloaded: _matchaDownloaded,
              downloading: _matchaDownloading,
              progress: _matchaProgress,
              onDownload: _downloadMatcha,
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

  Widget _buildDownloadTile({
    required String label,
    required bool downloaded,
    required bool downloading,
    required double progress,
    required VoidCallback onDownload,
  }) {
    if (downloading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloading $label... ${(progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
          ],
        ),
      );
    }

    if (downloaded) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text('$label ready'),
      );
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.download, color: Colors.deepPurpleAccent),
      title: Text('$label not downloaded'),
      subtitle: const Text('Tap to download'),
      trailing: ElevatedButton(
        onPressed: onDownload,
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
