import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/mood.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/chat_provider.dart';
import '../../../core/ai/managed_runtime.dart';
import '../../../core/audio/voice_service.dart';
import '../../../core/data/memory_provider.dart';
import '../../../core/data/web_search_service.dart';
import '../../../core/data/reminder_service.dart';
import '../../../shared/widgets/audio_visualizer.dart';
import '../../../shared/widgets/mood_aura.dart';
import '../../memory/screens/memory_view_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

final voiceServiceProvider = Provider((ref) {
  final service = VoiceService();
  return service;
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isVoiceMode = false;
  bool _isInitializing = true;
  String _loadingStatus = "Starting up...";
  late ManagedRuntime _runtime;
  late VoiceService _voiceService;
  StreamSubscription? _sttSubscription;
  StreamSubscription<String>? _generationSubscription;
  bool _isGenerating = false;
  bool _isAgentSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    _runtime = ManagedRuntime();
    _voiceService = ref.read(voiceServiceProvider);
    
    setState(() => _loadingStatus = "Loading AI Engine...");
    await _runtime.initialize();
    _runtime.resetConversation(_buildSystemInstruction(ref.read(settingsProvider)));
    
    setState(() => _loadingStatus = "Loading Voice Services...");
    await _voiceService.initialize();
    
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    
    _voiceService.onSpeakingStarted = () {
      if (mounted && _isVoiceMode) setState(() => _isAgentSpeaking = true);
    };
    _voiceService.onSpeakingComplete = () {
      if (_isVoiceMode) _voiceService.resumeActiveListening();
      if (mounted) setState(() => _isAgentSpeaking = false);
    };

    final reminderService = ref.read(reminderServiceProvider);
    await reminderService.initialize();
    reminderService.onReminderTapped.listen((payload) {
      if (payload.startsWith('REMINDER_TRIGGERED|') && mounted) {
         final title = payload.split('|')[1];
         _handleUserInput("I just opened my reminder titled '$title'. Please remind me about this right now.", fromVoice: false, injectedContext: "User clicked the reminder notification. Speak directly to them about it.");
      }
    });
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _sttSubscription?.cancel();
    super.dispose();
  }

  void _toggleVoiceMode() {
    if (_isVoiceMode) {
      _exitVoiceMode();
    } else {
      _enterVoiceMode();
    }
  }

  void _enterVoiceMode() {
    _voiceService.stopSpeaking();
    setState(() => _isVoiceMode = true);

    _sttSubscription = _voiceService.startSTT().listen((text) {
      if (text == '[DONE]') {
        _onUserFinishedSpeaking();
      } else if (text == '[BARGE_IN]') {
        _onBargein();
      } else if (text.isNotEmpty) {
        setState(() => _textController.text = text);
      }
    });
  }

  Future<void> _exitVoiceMode() async {
    setState(() {
      _isVoiceMode = false;
      _isAgentSpeaking = false;
    });
    _voiceService.stopSpeaking();
    _sttSubscription?.cancel();
    _sttSubscription = null;
    await _voiceService.stopSTT();
  }

  // Called when Sherpa-ONNX endpoint fires. Keep the recorder running for
  // barge-in monitoring while the AI responds; do not exit voice mode.
  void _onUserFinishedSpeaking() {
    final text = _textController.text.trim();
    _textController.clear();
    if (text.isNotEmpty) {
      _voiceService.startBargeinMonitor();
      _handleUserInput(text, fromVoice: true);
    }
    // If text is empty (noise/silence endpoint), stay in active listening mode.
  }

  // Called when the user speaks while the AI is talking. Cancel the in-flight
  // generation, discard the partial AI response, and resume listening.
  void _onBargein() {
    _generationSubscription?.cancel();
    _generationSubscription = null;
    ref.read(chatHistoryProvider.notifier).removeLastMessage();
    setState(() => _textController.clear());
    // _isBargeinMonitoring was already cleared in VoiceService before firing
    // [BARGE_IN], so the STT stream is already back in active-listening mode.
  }

  // Assembles the full personality + tool directives for the LiteRT-LM system
  // instruction. Called once on init and again whenever the mood changes.
  String _buildSystemInstruction(SettingsState settings) {
    final moodPrompt = settings.moodPrompts[settings.currentMood] ?? '';
    final autonomousDirective = settings.autonomousMoodSwitching
        ? 'Before you respond, choose the most appropriate mood for the situation. You MUST start your response exactly with [MOOD: professional|excited|angry|romantic|sad|sarcastic] where you pick one of those 6 moods. Then provide your response.'
        : '';
    final searchDirective = settings.enableWebSearch
        ? 'If you need to search the internet for an answer to a question you do not know, append [SEARCH_WEB: query] to your response. You must wait for the search results to be provided.'
        : '';
    final imageDirective = settings.enableWebSearch
        ? 'If the user asks for a picture or image of something, append [SEARCH_IMAGE: query] at the end of your response to search for and display an image.'
        : '';
    return settings.systemContextTemplate
        .replaceAll('{name}', settings.agentName)
        .replaceAll('{attitude}', settings.agentAttitude)
        .replaceAll('{mood}', moodPrompt)
        .replaceAll('{autonomous_directive}', autonomousDirective)
        .replaceAll('{search_directive}', searchDirective)
        .replaceAll('{image_directive}', imageDirective);
  }

  void _stopGeneration() {
    _generationSubscription?.cancel();
    _generationSubscription = null;
    _voiceService.stopSpeaking();
    setState(() {
      _isGenerating = false;
      _isAgentSpeaking = false;
    });
  }

  void _handleUserInput(String text, {bool fromVoice = false, String? injectedContext, String? originalUserText}) {
    // Stop any current speech when a new interaction starts
    _voiceService.stopSpeaking();
    setState(() => _isGenerating = true);
    
    if (injectedContext == null) {
      ref.read(chatHistoryProvider.notifier).addMessage(text, true);
    }
    ref.read(chatHistoryProvider.notifier).addMessage(injectedContext != null ? "Searching the web..." : "", false);
    
    final settings = ref.read(settingsProvider);
    final now = DateTime.now().toLocal();
    int hour = now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final formattedTime = "$hour:$minute $period";
    
    final timeContext = "Current time context: ${now.month}/${now.day}/${now.year} $formattedTime";
    
    final memories = ref.read(memoryProvider);
    final memoryContext = memories.isNotEmpty 
        ? "Facts you remember about the user:\n- " + memories.join("\n- ") 
        : "";
        
    final augmentedPrompt = injectedContext != null
        ? "$timeContext\n$memoryContext\n\nUser: ${originalUserText ?? ''}\n$injectedContext"
        : "$timeContext\n$memoryContext\n\nUser: $text";

    String currentPhrase = "";
    String fullResponse = "";
    _generationSubscription = _runtime.generate(augmentedPrompt).listen((token) {
       currentPhrase += token;
       fullResponse += token;
       
       String displayResponse = fullResponse;
       if (settings.autonomousMoodSwitching) {
         final moodMatch = RegExp(r'^\[MOOD:\s*([a-zA-Z]+)\]\s*').firstMatch(fullResponse);
         if (moodMatch != null) {
           final moodStr = moodMatch.group(1)!.toLowerCase();
           final newMood = MoodType.values.firstWhere(
             (e) => e.name == moodStr, 
             orElse: () => ref.read(settingsProvider).currentMood,
           );
           if (newMood != ref.read(settingsProvider).currentMood) {
             ref.read(settingsProvider.notifier).updateMood(newMood);
           }
           displayResponse = fullResponse.substring(moodMatch.end);
           // Strip the mood prefix from the TTS buffer so it is never spoken.
           currentPhrase = currentPhrase.replaceFirst(RegExp(r'^\[MOOD:\s*[a-zA-Z]+\]\s*'), '');
         } else if (fullResponse.startsWith('[') && !fullResponse.contains(']')) {
           displayResponse = injectedContext != null && ref.read(chatHistoryProvider).last.text == "Searching the web..." 
               ? "Searching the web..." 
               : "";
         }
       }
       
       if (displayResponse.isNotEmpty || injectedContext == null) {
         ref.read(chatHistoryProvider.notifier).replaceLastMessage(displayResponse);
       }
       
       if (fromVoice) {
         if (currentPhrase.contains('[SAVE_MEMORY:') || currentPhrase.contains('[SEARCH_WEB:') || currentPhrase.contains('[REMIND_ME:') || currentPhrase.contains('[SEARCH_IMAGE:')) {
           return; // Wait until stream finishes to avoid speaking the tag
         }
         
         // Detect end of a sentence or a meaningful chunk
         if (currentPhrase.trim().length > 8 && currentPhrase.contains(RegExp(r'[,.!?\n]'))) {
            if (!currentPhrase.contains('[')) {
              _voiceService.speak(currentPhrase);
              currentPhrase = "";
            }
         }
       }
    }, onError: (error) {
      _generationSubscription = null;
      setState(() => _isGenerating = false);
      ref.read(chatHistoryProvider.notifier).updateLastMessage("\n\n[Error: The AI engine encountered an unexpected hardware/GPU failure. Please try asking again.]");
      _voiceService.stopSpeaking();
    }, onDone: () {
      _generationSubscription = null;
      setState(() => _isGenerating = false);
      final lastMsg = ref.read(chatHistoryProvider).last;
      String text = lastMsg.text;
      
      final memoryMatch = RegExp(r'\[SAVE_MEMORY:\s*(.*?)(?:\]|$)', dotAll: true).firstMatch(text);
      if (memoryMatch != null) {
         final factToSave = memoryMatch.group(1)!.trim();
          if (factToSave.isNotEmpty) {
            ref.read(memoryProvider.notifier).saveMemory(factToSave);
          }
       }
       
       final reminderMatch = RegExp(r'\[REMIND_ME:\s*(.*?)\s*\|\s*(.*?)\]', dotAll: true).firstMatch(text);
       if (reminderMatch != null) {
          final title = reminderMatch.group(1)!.trim();
          final dateStr = reminderMatch.group(2)!.trim();
          try {
            final scheduledTime = DateTime.parse(dateStr);
            ref.read(reminderServiceProvider).scheduleReminder(title, scheduledTime);
          } catch (e) {
            print("Failed to parse reminder date: $dateStr");
          }
       }

       final searchMatch = RegExp(r'\[SEARCH_WEB:\s*(.*?)(?:\]|$)', dotAll: true).firstMatch(text);
      if (searchMatch != null && settings.enableWebSearch) {
         final query = searchMatch.group(1)!.trim();
         text = text.replaceAll(searchMatch.group(0)!, '').trim();
         if (text.isEmpty) text = "Searching the web for '$query'...";
         ref.read(chatHistoryProvider.notifier).replaceLastMessage(text);
         
         final searchService = ref.read(webSearchServiceProvider);
         searchService.search(query).then((results) {
           final resultContext = "[WEB SEARCH RESULTS FOR '$query']:\n$results\n\nNow answer the user's question using these results.";
           _handleUserInput(
             text, 
             fromVoice: fromVoice, 
             injectedContext: resultContext,
             originalUserText: originalUserText ?? text,
           );
         });
         return; // Skip TTS for the searching message
      }
      
      final imageMatch = RegExp(r'\[SEARCH_IMAGE:\s*(.*?)(?:\]|$)', dotAll: true).firstMatch(text);
      if (imageMatch != null && settings.enableWebSearch) {
         final query = imageMatch.group(1)!.trim();
         text = text.replaceAll(imageMatch.group(0)!, '').trim();
         ref.read(chatHistoryProvider.notifier).replaceLastMessage(text);
         
         final searchService = ref.read(webSearchServiceProvider);
         searchService.searchImage(query).then((imageUrl) {
           if (imageUrl != null) {
              ref.read(chatHistoryProvider.notifier).replaceLastMessage(text, imageUrl: imageUrl);
           }
         });
      }

      if (fromVoice && currentPhrase.isNotEmpty) {
        final cleanPhrase = currentPhrase
            .replaceAll(RegExp(r'^\[MOOD:\s*[a-zA-Z]+\]\s*'), '')
            .replaceAll(RegExp(r'\[SAVE_MEMORY:\s*(.*?)(?:\]|$)', dotAll: true), '')
            .replaceAll(RegExp(r'\[SEARCH_WEB:\s*(.*?)(?:\]|$)', dotAll: true), '')
            .replaceAll(RegExp(r'\[REMIND_ME:\s*(.*?)\s*\|\s*(.*?)(?:\]|$)', dotAll: true), '')
            .replaceAll(RegExp(r'\[SEARCH_IMAGE:\s*(.*?)(?:\]|$)', dotAll: true), '')
            .trim();
        if (cleanPhrase.isNotEmpty) {
          _voiceService.speak(cleanPhrase);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final history = ref.watch(chatHistoryProvider);
    
    // Keep voice service in sync with settings
    _voiceService.useSystemTts = settings.useSystemTts;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MoodAura(
              mood: settings.currentMood,
              color: settings.currentMood.color,
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
        title: Text(settings.agentName),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Mood',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: MoodType.values.map((type) {
                            return ChoiceChip(
                              label: Text(type.label),
                              selected: settings.currentMood == type,
                              onSelected: (selected) {
                                if (selected) {
                                  ref.read(settingsProvider.notifier).updateMood(type);
                                  _runtime.resetConversation(
                                    _buildSystemInstruction(ref.read(settingsProvider)),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              selectedColor: type.color.withOpacity(0.3),
                              labelStyle: TextStyle(
                                color: settings.currentMood == type ? type.color : Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: settings.currentMood.color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getMoodIcon(settings.currentMood),
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'Agent Memory',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MemoryViewScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                _runtime.resetConversation(
                  _buildSystemInstruction(ref.read(settingsProvider)),
                );
              });
            },
          ),
        ],
      ),
      body: _isInitializing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    _loadingStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _voiceService.stopSpeaking(),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final message = history[history.length - 1 - index];
                            return _buildMessageBubble(message, settings.currentMood.color);
                          },
                        ),
                      ),
                      if (!_isVoiceMode) _buildInputArea(settings.currentMood.color),
                    ],
                  ),
                  if (_isVoiceMode) _buildVoiceOverlay(settings.currentMood.color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceOverlay(Color moodColor) {
    final String label;
    final Widget indicator;
    final bool busy = _isGenerating || _isAgentSpeaking;

    if (_isGenerating) {
      label = 'Thinking...';
      indicator = SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(color: moodColor, strokeWidth: 3),
      );
    } else if (_isAgentSpeaking) {
      label = 'Speaking...';
      indicator = AudioVisualizer(isListening: true);
    } else {
      label = 'Listening...';
      indicator = AudioVisualizer(isListening: true);
    }

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                label,
                key: ValueKey(label),
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 48),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: SizedBox(key: ValueKey(_isGenerating), child: indicator),
            ),
            const SizedBox(height: 48),
            if (!busy)
              Text(
                _textController.text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
            const SizedBox(height: 64),
            GestureDetector(
              onTap: busy ? _stopGeneration : _exitVoiceMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: busy ? Colors.red.shade700 : moodColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stop, color: Colors.white, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (BuildContext context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black.withOpacity(0.95),
            body: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Hero(
                        tag: imageUrl,
                        child: Image.network(imageUrl),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.download, color: Colors.black),
                    onPressed: () async {
                      try {
                        final tempDir = await getTemporaryDirectory();
                        final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                        await Dio().download(imageUrl, path);
                        await Gal.putImage(path);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image saved to gallery!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save image: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(Message message, Color moodColor) {
    bool hasMemory = message.text.contains('[SAVE_MEMORY:');
    bool hasReminder = message.text.contains('[REMIND_ME:');
    bool hasImage = message.text.contains('[SEARCH_IMAGE:');
    String displayText = message.text;
    
    if (hasMemory) {
      displayText = displayText.replaceAll(RegExp(r'\[SAVE_MEMORY:\s*(.*?)(?:\]|$)', dotAll: true), '').trim();
    }
    if (hasReminder) {
      displayText = displayText.replaceAll(RegExp(r'\[REMIND_ME:\s*(.*?)\s*\|\s*(.*?)(?:\]|$)', dotAll: true), '').trim();
    }
    if (hasImage) {
      displayText = displayText.replaceAll(RegExp(r'\[SEARCH_IMAGE:\s*(.*?)(?:\]|$)', dotAll: true), '').trim();
    }

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (displayText.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: displayText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message copied to clipboard!')),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: message.isUser ? moodColor : AppColors.surface,
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomRight: message.isUser ? Radius.zero : null,
              bottomLeft: !message.isUser ? Radius.zero : null,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (displayText.isNotEmpty)
                Text(
                  displayText,
                  style: const TextStyle(color: Colors.white),
                ),
              if (message.imageUrl != null)
                Padding(
                  padding: EdgeInsets.only(top: displayText.isNotEmpty ? 12.0 : 0),
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(context, message.imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Hero(
                        tag: message.imageUrl!,
                        child: Image.network(
                          message.imageUrl!,
                          width: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Text('Image failed to load', style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasMemory || hasReminder)
                Padding(
                  padding: EdgeInsets.only(top: displayText.isNotEmpty ? 8.0 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasMemory) ...[
                        const Icon(Icons.psychology, color: Colors.white70, size: 18),
                        const SizedBox(width: 4),
                        const Text('Memory Saved', style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                        if (hasReminder) const SizedBox(width: 12),
                      ],
                      if (hasReminder) ...[
                        const Icon(Icons.notifications_active, color: Colors.white70, size: 18),
                        const SizedBox(width: 4),
                        const Text('Reminder Set', style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(Color moodColor) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: _toggleVoiceMode,
          ),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: moodColor,
                  selectionColor: moodColor.withOpacity(0.3),
                  selectionHandleColor: moodColor,
                ),
              ),
              child: TextField(
                controller: _textController,
                cursorColor: moodColor,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: moodColor, width: 2),
                  ),
                ),
                onSubmitted: (text) {
                  if (text.isNotEmpty) {
                    _handleUserInput(text, fromVoice: false);
                    _textController.clear();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isGenerating ? Colors.red.shade700 : moodColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isGenerating ? Icons.stop : Icons.send,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _isGenerating
                  ? _stopGeneration
                  : () {
                      final text = _textController.text;
                      if (text.isNotEmpty) {
                        _handleUserInput(text, fromVoice: false);
                        _textController.clear();
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMoodIcon(MoodType mood) {
    switch (mood) {
      case MoodType.professional: return Icons.business_center;
      case MoodType.excited: return Icons.celebration;
      case MoodType.angry: return Icons.mood_bad;
      case MoodType.romantic: return Icons.favorite;
      case MoodType.sad: return Icons.sentiment_dissatisfied;
      case MoodType.sarcastic: return Icons.sentiment_neutral;
    }
  }
}
