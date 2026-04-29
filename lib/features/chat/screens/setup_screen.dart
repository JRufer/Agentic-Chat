import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/utils/hardware_profiler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ai/download_manager.dart';
import 'chat_screen.dart'; 

final hardwareInfoProvider = FutureProvider<HardwareInfo>((ref) async {
  return await HardwareProfiler.profile();
});

final downloadProgressProvider = StateProvider<double>((ref) => 0.0);

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  bool _isDownloading = false;
  final TextEditingController _tokenController = TextEditingController();
  static const String _tokenKey = 'hf_token';

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    if (savedToken != null) {
      _tokenController.text = savedToken;
    }

    // Check if models already exist
    final appDocDir = await getApplicationDocumentsDirectory();
    final requiredModels = [
      'models/gemma_v4_final.litertlm',
      'models/embeddings.onnx',
      'models/stt_encoder.onnx',
      'models/stt_decoder.onnx',
      'models/stt_joiner.onnx',
      'models/stt_tokens.txt',
      'models/tts_vits_model.onnx',
      'models/tts_vits_tokens.txt',
      'models/tts_vits_lexicon.txt',
    ];

    bool allExist = true;
    for (var path in requiredModels) {
      if (!await File('${appDocDir.path}/$path').exists()) {
        allExist = false;
        break;
      }
    }

    if (allExist) {
      // If models exist, we can proceed to ChatScreen automatically
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ChatScreen()),
        );
      }
    }
  }

  Future<void> _startSetup(HardwareInfo info) async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _showErrorAndAllowSkip("Hugging Face token is required for gated models.");
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final downloader = ref.read(modelDownloadProvider);
      final headers = {"Authorization": "Bearer $token"};
      
      // User-verified Gemma 4 LiteRT-LM repository
      const gemmaUrl = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true";
      const embedderUrl = "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/onnx/model.onnx?download=true";
      
      // Voice Models
      const voiceModels = {
        "stt_encoder.onnx": "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/main/encoder-epoch-99-avg-1-chunk-16-left-64.onnx",
        "stt_decoder.onnx": "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/main/decoder-epoch-99-avg-1-chunk-16-left-64.onnx",
        "stt_joiner.onnx": "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/main/joiner-epoch-99-avg-1-chunk-16-left-64.onnx",
        "stt_tokens.txt": "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/main/tokens.txt",
        "tts_vits_model.onnx": "https://huggingface.co/csukuangfj/vits-ljs/resolve/main/vits-ljs.onnx",
        "tts_vits_tokens.txt": "https://huggingface.co/csukuangfj/vits-ljs/resolve/main/tokens.txt",
        "tts_vits_lexicon.txt": "https://huggingface.co/csukuangfj/vits-ljs/resolve/main/lexicon.txt",
        "silero_vad.onnx": "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx",
      };

      try {
        debugPrint("Starting download of gemma_v4_final.litertlm...");
        await downloader.downloadModel(
          gemmaUrl, 
          "gemma_v4_final.litertlm", 
          (p) => ref.read(downloadProgressProvider.notifier).state = p * 0.4,
          headers: headers,
        );

        debugPrint("Starting download of embeddings.onnx...");
        await downloader.downloadModel(
          embedderUrl, 
          "embeddings.onnx", 
          (p) => ref.read(downloadProgressProvider.notifier).state = 0.4 + (p * 0.1),
          headers: headers,
        );

        int count = 0;
        for (var entry in voiceModels.entries) {
          debugPrint("Starting download of ${entry.key}...");
          await downloader.downloadModel(
            entry.value,
            entry.key,
            (p) => ref.read(downloadProgressProvider.notifier).state = 0.5 + ((count + p) / voiceModels.length) * 0.5,
            headers: headers,
          );
          count++;
        }
      } catch (downloadErr) {
        debugPrint("Download error details: $downloadErr");
        String detail = downloadErr.toString();
        if (detail.contains("404")) {
           detail = "404 Not Found: The model file URL is invalid or has moved. Please check litert-community on Hugging Face.";
        } else if (detail.contains("403")) {
           detail = "403 Forbidden: You must accept the Gemma license for EACH organization (Google AND litert-community).";
        }
        throw Exception(detail);
      }

      if (mounted) {
        // Save token for future use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ChatScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        String message = e.toString();
        
        if (e is DioException && e.response != null) {
           final responseData = e.response?.data;
           if (responseData is Map && responseData.containsKey('error')) {
             message = "Hugging Face Error: ${responseData['error']}";
           } else if (e.response?.statusCode == 403) {
             message = "403 Forbidden: License not accepted or Token lacks permissions. Visit hf.co/google/gemma-2b-it-tflite to accept terms.";
           }
        }
        
        _showErrorAndAllowSkip(message);
      }
    }
  }

  void _showErrorAndAllowSkip(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup Notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            const Text('Troubleshooting:\n1. Accept license at huggingface.co/google/gemma-2b-it-tflite\n2. Use a "Read" token from hf.co/settings/tokens\n3. Or proceed with Mock Mode.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retry'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => ChatScreen()),
              );
            },
            child: const Text('Proceed (Mock Mode)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hardwareInfo = ref.watch(hardwareInfoProvider);
    final progress = ref.watch(downloadProgressProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                _isDownloading ? 'Downloading Intelligence...' : 'Initializing Agentic Intelligence',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_isDownloading)
                Column(
                  children: [
                    LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: AppColors.surface, color: AppColors.secondary),
                    const SizedBox(height: 8),
                    Text('${(progress * 100).toStringAsFixed(1)}% complete'),
                  ],
                )
              else
                Column(
                  children: [
                    const Text(
                      'This app uses Gemma 4, which is a gated model. You must authorize access to begin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('1. Accept Gemma License'),
                      onPressed: () => launchUrl(Uri.parse('https://huggingface.co/google/gemma-2b-it-tflite')),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.key, size: 18),
                      label: const Text('2. Get HF Access Token'),
                      onPressed: () => launchUrl(Uri.parse('https://huggingface.co/settings/tokens')),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Hugging Face Token (read)',
                        hintText: 'hf_...',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.vpn_key),
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              if (!_isDownloading)
                hardwareInfo.when(
                  data: (info) => _buildRecommendation(context, info),
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Text('Error: $err'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendation(BuildContext context, HardwareInfo info) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Text(
                'Hardware Detected: ${info.ramGB}GB RAM, ${info.cpuCores} Cores',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Recommendation: Gemma 4 ${info.recommendedVariant == GemmaVariant.e4b ? "E4B" : "E2B"}',
                style: const TextStyle(color: AppColors.secondary, fontSize: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => _startSetup(info),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Authorize & Download'),
        ),
      ],
    );
  }
}
