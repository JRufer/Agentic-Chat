import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/memory_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../shared/widgets/mood_aura.dart';

class MemoryViewScreen extends ConsumerWidget {
  const MemoryViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoryProvider);
    final settings = ref.watch(settingsProvider);

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
              title: const Text('Agent Memory'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                if (memories.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    tooltip: 'Clear All',
                    onPressed: () => _confirmClear(context, ref),
                  ),
              ],
            ),
            body: memories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology_outlined, size: 80, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text(
                          'No memories stored yet.',
                          style: TextStyle(color: Colors.white54, fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: memories.length,
                    itemBuilder: (context, index) {
                      final memory = memories[index];
                      return _buildMemoryCard(context, ref, memory);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(BuildContext context, WidgetRef ref, String memory) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    memory,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38),
                  onPressed: () {
                    ref.read(memoryProvider.notifier).removeMemory(memory);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear All Memories?'),
        content: const Text('This will permanently delete everything the agent knows about you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(memoryProvider.notifier).clearMemories();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
